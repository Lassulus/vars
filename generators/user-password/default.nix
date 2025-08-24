{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.vars.user-password;
in
{
  imports = [
    ../options.nix
  ];
  options.vars.user-password = {
    enable = lib.mkEnableOption ''
      Automatically generates and configures a password for a user.

      This will set `mutableUsers` to `false`, meaning you can not manage user passwords through `passwd` anymore.
    '';
    users = lib.mkOption {
      type = lib.types.attrsOf (lib.submodule {
        options = {
          prompt = lib.mkOption {
            type = lib.types.bool;
            default = !config.vars.unattended;
            example = true;
            description = "Whether the user should be prompted.";
          };
        };
      });
      description = "The users for which to generate passwords.";
      example = "{ alice = { }; }";
    };
  };

  config = lib.mkIf cfg.enable {
    users.mutableUsers = false;
    users.users = lib.mapAttrs (userName: _: {
      hashedPasswordFile = config.vars.generators."user-password-${userName}".files.user-password-hash.path;
      isNormalUser = lib.mkDefault true;
    }) cfg.users;

    vars.generators = lib.mapAttrs (userName: user: {
      "user-password-${userName}" = {
        files.user-password-hash.neededFor = "users";
        files.user-password-hash.restartUnits = lib.optional (config.services.userborn.enable) "userborn.service";

        prompts = lib.mkIf user.prompt {
          "user-password-${userName}" = {
            type = "hidden";
            persist = true;
            description = "You can autogenerate a password, if you leave this prompt blank.";
            files.user-password.deploy = false;
          };
        };

        runtimeInputs = [
          pkgs.coreutils
          pkgs.xkcdpass
          pkgs.mkpasswd
        ];
        script = ''
          prompt_value=${if user.prompt then ''$(cat "$prompts"/user-password)'' else ""}
          if [[ -n "''${prompt_value-}" ]]; then
            echo "$prompt_value" | tr -d "\n" > "$out"/user-password
          else
            xkcdpass --numwords 3 --delimiter - --count 1 | tr -d "\n" > "$out"/user-password
          fi
          mkpasswd -s -m sha-512 < "$out"/user-password | tr -d "\n" > "$out"/user-password-hash
        '';
      };
    }) cfg.users;
  };
}
