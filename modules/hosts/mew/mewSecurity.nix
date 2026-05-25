{ self, ... }: {
  flake.nixosModules.mewSecurity = { pkgs, ... }: {
    imports = [
      self.nixosModules.yubikey
      self.nixosModules.fprintd
      self.nixosModules.mewDisko
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

    security.pam.u2f.settings.authfile = pkgs.writeText "u2f_mappings" ''
      phaedrus:am2PA7XnzRU724oXbPER2cZscCPsxuJ6c9a9TBzhiO0H4rFifS8uonAX4LGz2FlhKcIlbueg/gl75ejrZflAdw==,WSmqHMmgzkkia4Eu+PxvrnYwtDfHh59yviJ4JPNvHNOd4PWmRqaKmv9E7+5LXHwOSoj5q+KyfOO20k5IIaJfww==,es256,+presence:OsEGEekmhje9VOdr1ZK8NlyTWFBQaIQ/XjLOTWG44s6Bqc10wE++Zib6UImsODIyqpXrj+HjfmJCvViqpMsR4A==,agMpdjC+7F7H7M+S0pTTgw6uP9N9Nyyk8fgx4qRDJTw7K8zfsqpvEU3/GK1kTUNTEyxNt2L8CLM2ifkQ1BezWw==,es256,+presence
    '';

    # locks computer when closed
    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "suspend";
    };
  };
}