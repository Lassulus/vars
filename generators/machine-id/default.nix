{
  config,
  lib,
  pkgs,
  ...
}:
let
  var = config.vars.generators.machine-id.files.machineId or { };
  cfg = config.vars.machine-id;
in
{
  options.vars.machine-id.enable = lib.mkEnableOption "Sets the /etc/machine-id and exposes it as a nix option";
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf ((var.value or null) != null) {
      assertions = [
        {
          assertion = lib.stringLength var.value == 32;
          message = "machineId must be exactly 32 characters long.";
        }
      ];
      boot.kernelParams = [
        ''systemd.machine_id=${var.value}''
      ];
      environment.etc."machine-id" = {
        text = var.value;
      };
    })
    {
      vars.generators.machine-id = {
        files.machineId.secret = false;
        runtimeInputs = [
          pkgs.coreutils
          pkgs.bash
        ];
        script = ''
          uuid=$(bash ${./uuid4.sh})

          # Remove the hyphens from the UUID
          uuid_no_hyphens=$(echo -n "$uuid" | tr -d '-')

          echo -n "$uuid_no_hyphens" > "$out/machineId"
        '';
      };
    }
  ]);
}
