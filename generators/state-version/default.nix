{ config, lib, ... }:
let
  var = config.vars.generators.state-version.files.version or { };
  cfg = config.vars.state-version;
in
{
  options.vars.state-version.enable = lib.mkEnableOption "Automatically generate the state version of the nixos installation.";
  config = lib.mkIf cfg.enable {
    system.stateVersion = lib.mkDefault (lib.removeSuffix "\n" var.value);

    vars.generators.state-version = {
      files.version = {
        secret = false;
        value = lib.mkDefault config.system.nixos.release;
      };
      runtimeInputs = [ ];
      script = ''
        echo -n ${config.system.stateVersion} > "$out"/version
      '';
    };
  };
}
