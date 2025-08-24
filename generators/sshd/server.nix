{
  config,
  pkgs,
  lib,
  ...
}:
let
  stringSet = list: builtins.attrNames (builtins.groupBy lib.id list);

  domains = stringSet config.vars.sshd.certificate.searchDomains;

  cfg = config.vars.sshd;

  name = config.networking.hostName;
in
{
  imports = [ ../shared.nix ];
  options = {
    vars.sshd = {
      enable = lib.mkEnableOption "Set up the opensshd service, generating a host key for the machine.";
      hostKeys.rsa.enable = lib.mkEnableOption "Generate RSA host key";
    };
  };
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;

      settings.HostCertificate = lib.mkIf (
        cfg.certificate.searchDomains != [ ]
      ) config.vars.generators.openssh-cert.files."ssh.id_ed25519-cert.pub".path;

      hostKeys =
        [
          {
            path = config.vars.generators.openssh.files."ssh.id_ed25519".path;
            type = "ed25519";
          }
        ]
        ++ lib.optional cfg.hostKeys.rsa.enable {
          path = config.vars.generators.openssh-rsa.files."ssh.id_rsa".path;
          type = "rsa";
        };
    };

    vars.generators.openssh = {
      files."ssh.id_ed25519" = { };
      files."ssh.id_ed25519.pub".secret = false;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.openssh
      ];
      script = ''
        ssh-keygen -t ed25519 -N "" -f "$out"/ssh.id_ed25519
      '';
    };

    programs.ssh.knownHosts.sshd-self-ed25519 = {
      hostNames = [
        "localhost"
        config.networking.hostName
      ] ++ (lib.optional (config.networking.domain != null) config.networking.fqdn);
      publicKey = config.vars.generators.openssh.files."ssh.id_ed25519.pub".value;
    };

    vars.generators.openssh-rsa = lib.mkIf config.vars.sshd.hostKeys.rsa.enable {
      files."ssh.id_rsa" = { };
      files."ssh.id_rsa.pub".secret = false;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.openssh
      ];
      script = ''
        ssh-keygen -t rsa -b 4096 -N "" -f "$out"/ssh.id_rsa
      '';
    };

    vars.generators.openssh-cert = lib.mkIf (cfg.certificate.searchDomains != [ ]) {
      files."ssh.id_ed25519-cert.pub".secret = false;
      dependencies = [
        "openssh"
        "openssh-ca"
      ];
      validation = {
        inherit name;
        domains = lib.genAttrs config.vars.sshd.certificate.searchDomains lib.id;
      };
      runtimeInputs = [
        pkgs.openssh
        pkgs.jq
      ];
      script = ''
        ssh-keygen \
          -s $in/openssh-ca/id_ed25519 \
          -I ${name} \
          -h \
          -n ${lib.concatMapStringsSep "," (d: "${name}.${d}") domains} \
          $in/openssh/ssh.id_ed25519.pub
        mv $in/openssh/ssh.id_ed25519-cert.pub "$out"/ssh.id_ed25519-cert.pub
      '';
    };
  };
}
