{ self, ... }: {
  flake.nixosModules.mewSecurity = { pkgs, ... }: {
    imports = [
      self.nixosModules.yubikey
      self.nixosModules.fprintd
      self.nixosModules.mewDisko
      # self.nixosModules.mewSops
      # self.nixosModules.sops
    ];

    # PIV-backed SSH via OpenSC — private key never leaves the YubiKey hardware
    programs.ssh.extraConfig = ''
      Host *.home
        PKCS11Provider ${pkgs.opensc}/lib/opensc-pkcs11.so
      Host github.com
        PKCS11Provider ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';

    environment.systemPackages = [ pkgs.opensc ];

    # Route SSH agent through GPG agent (used for PIV key signing)
    environment.sessionVariables = {
      SSH_AUTH_SOCK = "/run/user/1000/gnupg/S.gpg-agent.ssh";
    };
  };
}