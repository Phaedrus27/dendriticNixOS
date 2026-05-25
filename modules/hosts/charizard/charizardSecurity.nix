{ self, ... }: {
  flake.nixosModules.charizardSecurity = { pkgs, ... }: {
    imports = [ self.nixosModules.yubikey ];

    # Squirtle backup job SSHes into charizard using this key
    users.users.phaedrus.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICy71fHrSglydDTpHaoPGmwAqQNn9Z3DbMWQ2B41gWDn squirtle-backup"
    ];

    # PIV-backed SSH — private key never leaves the YubiKey hardware
    programs.ssh.extraConfig = ''
      Host *.home
        PKCS11Provider ${pkgs.opensc}/lib/opensc-pkcs11.so
      Host github.com
        PKCS11Provider ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';

    environment.systemPackages = [ pkgs.opensc ];

    environment.sessionVariables = {
      SSH_AUTH_SOCK = "/run/user/1000/gnupg/S.gpg-agent.ssh";
    };

    # pam_u2f — YubiKey touch for sudo
    # Generated with: pamu2fcfg > /tmp/u2f && pamu2fcfg -n >> /tmp/u2f (swap keys between commands)
    security.pam.u2f.settings.authfile = pkgs.writeText "u2f_mappings" ''
      phaedrus:bQGIdVctyjerQS1Wzv8APAItVDoI6BY+l2gFJ9sdsGb5+KrV8MQyiMcuqHxkdq698HTySteDq3J+aMg18P21fg==,rakcy2MsQK9TqTHsWxXsg/0th31SlzzG34KZRChDXioO2EddQeNngExrXMtWD3G8ErQkByTz40rrPxD3TWjfmw==,es256,+presence:grSTD34kpGp0s86ctats3Ax86TKFj9bHlEZcEIDUWBshQPIH/+JjaQdIg3A59HqLnDVkh1O/UtPVkN45rt4njw==,vNpjvNCAfc25gbOQfBkf6NXtevXfrXHMUXGP+BXtdqq2JdxO89mnaH/JVbNa4g5cNudeznglwEOeFxWIpwKOPg==,es256,+presence
    '';
  };
}