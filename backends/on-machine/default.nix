# we use this vars backend as an example backend.
# this generates a script which creates the values at the expected path.
# this script has to be run manually (I guess after updating the system) to generate the required vars.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.vars.settings.on-machine;
  sortedGenerators =
    (lib.toposort (a: b: builtins.elem a.name b.dependencies) (lib.attrValues config.vars.generators))
    .result;

  promptCmd = {
    hidden = "read -sr prompt_value";
    line = "read -r prompt_value";
    multiline = ''
      echo 'press control-d to finish'
      prompt_value=$(cat)
    '';
  };
  generate-vars = pkgs.writeShellApplication {
    name = "generate-vars";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      _config=${pkgs.writers.writeJSON "generate-vars.json" {
        file_location = cfg.fileLocation;
        generators = sortedGenerators;
      }}

      ${builtins.readFile ./generate-secrets}
    '';
  };
in {
  options.vars.settings.on-machine = {
    enable = lib.mkEnableOption "Enable on-machine vars backend";
    fileLocation = lib.mkOption {
      type = lib.types.str;
      default = "/etc/vars";
    };
  };
  config = lib.mkIf cfg.enable {
    vars.settings.fileModule = file: {
      path =
        if file.config.secret
        then "${cfg.fileLocation}/secret/${file.config.generator}/${file.config.name}"
        else "${cfg.fileLocation}/public/${file.config.generator}/${file.config.name}";
    };
    environment.systemPackages = [
      generate-vars
    ];
    system.build.generate-vars = generate-vars;
  };
}
