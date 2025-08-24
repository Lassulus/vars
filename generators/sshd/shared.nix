{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vars.sshd.certificate;
in
{
  options.vars.sshd.certificate = {
    enable = lib.mkEnableOption "Add machines to the known hosts, enabling secure remote access to them over ssh.";
    searchDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mydomain.com" ];
      description = "List of domains to include in the certificate. This option will prepend the machine name in front of each domain before adding it to the certificate.";
    };
  };
  config = lib.mkIf cfg.enable {
    vars.generators.openssh-ca =
      lib.mkIf (config.vars.sshd.certificate.searchDomains != [ ])
        {
          share = true;
          files.id_ed25519.deploy = false;
          files."id_ed25519.pub" = {
            deploy = false;
            secret = false;
          };
          runtimeInputs = [
            pkgs.openssh
          ];
          script = ''
            ssh-keygen -t ed25519 -N "" -f "$out"/id_ed25519
          '';
        };

    programs.ssh.knownHosts.ssh-ca = lib.mkIf (config.vars.sshd.certificate.searchDomains != [ ]) {
      certAuthority = true;
      extraHostNames = builtins.map (domain: "*.${domain}") config.vars.sshd.certificate.searchDomains;
      publicKey = config.vars.generators.openssh-ca.files."id_ed25519.pub".value;
    };
  };
}
