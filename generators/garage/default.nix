{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vars.garage;
in
{
  options.vars.garage.enable = lib.mkEnableOption ''
    S3-compatible object store for small self-hosted geo-distributed deployments.

    This module generates garage-specific keys automatically.

    Options: [NixosModuleOptions](https://search.nixos.org/options?channel=unstable&size=50&sort=relevance&type=packages&query=garage)
    Documentation: https://garagehq.deuxfleurs.fr/
  '';
  config = lib.mkIf cfg.enable {
    systemd.services.garage.serviceConfig = {
      LoadCredential = [
        "rpc_secret_path:${config.vars.generators.garage-shared.files.rpc_secret.path}"
        "admin_token_path:${config.vars.generators.garage.files.admin_token.path}"
        "metrics_token_path:${config.vars.generators.garage.files.metrics_token.path}"
      ];
      Environment = [
        "GARAGE_ALLOW_WORLD_READABLE_SECRETS=true"
        "GARAGE_RPC_SECRET_FILE=%d/rpc_secret_path"
        "GARAGE_ADMIN_TOKEN_FILE=%d/admin_token_path"
        "GARAGE_METRICS_TOKEN_FILE=%d/metrics_token_path"
      ];
    };

    vars.generators.garage = {
      files.admin_token = { };
      files.metrics_token = { };
      runtimeInputs = [
        pkgs.coreutils
        pkgs.openssl
      ];
      script = ''
        openssl rand -base64 -out "$out"/admin_token 32
        openssl rand -base64 -out "$out"/metrics_token 32
      '';
    };

    vars.generators.garage-shared = {
      share = true;
      files.rpc_secret = { };
      runtimeInputs = [
        pkgs.coreutils
        pkgs.openssl
      ];
      script = ''
        openssl rand -hex -out "$out"/rpc_secret 32
      '';
    };
  };
}
