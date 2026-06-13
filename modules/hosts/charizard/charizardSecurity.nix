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
  };
}