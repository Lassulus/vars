{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vars.root-password;
in
{
  imports = [
    ../options.nix
  ];
  options.vars.root-password = {
    enable = lib.mkEnableOption "Automatically generates and configures a password for the root user.";
    prompt = lib.mkOption {
      type = lib.types.bool;
      default = !config.vars.unattended;
      example = true;
      description = "Whether the user should be prompted.";
    };
  };
  config = lib.mkIf cfg.enable {
    users.mutableUsers = false;
    users.users.root.hashedPasswordFile =
      config.vars.generators.root-password.files.password-hash.path;

    vars.generators.root-password = {
      files.password-hash = {
        neededFor = "users";
      };
      files.password-hash.restartUnits = lib.optional (config.services.userborn.enable) "userborn.service";
      files.password = {
        deploy = false;
      };
      runtimeInputs = [
        pkgs.coreutils
        pkgs.mkpasswd
        pkgs.xkcdpass
      ];
      prompts = lib.mkIf cfg.prompt {
        password = {
          type = "hidden";
          persist = true;
          description = "You can autogenerate a password, if you leave this prompt blank.";
        };
      };

      script = ''
        prompt_value=${if cfg.prompt then ''$(cat "$prompts"/password)'' else ""}
        if [[ -n "''${prompt_value-}" ]]; then
          echo "$prompt_value" | tr -d "\n" > "$out"/password
        else
          xkcdpass --numwords 3 --delimiter - --count 1 | tr -d "\n" > "$out"/password
        fi
        mkpasswd -s -m sha-512 < "$out"/password | tr -d "\n" > "$out"/password-hash
      '';
    };
  };
}
