{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vars.disk-id;
in
{
  options.vars.disk-id.enable = lib.mkEnableOption "Generates a uuid for use in disk device naming";
  config = lib.mkIf cfg.enable {
    vars.generators.disk-id = {
      files.diskId.secret = false;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.bash
      ];
      script = ''
        uuid=$(bash ${./uuid4.sh})

        # Remove the hyphens from the UUID
        uuid_no_hyphens=$(echo -n "$uuid" | tr -d '-')

        echo -n "$uuid_no_hyphens" > "$out/diskId"
      '';
    };
    disko.devices.disk."main".name = "main-" + config.vars.generators.disk-id.files.diskId.value;
  };
}
