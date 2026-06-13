{ self, ... }: {
  flake.nixosModules.mewSecurity = { pkgs, lib, ... }: {
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

    # Suspend on lid close. The lock itself is handled by noctalia's own
    # lockOnSuspend setting (settings.general.lockOnSuspend = true in
    # noctalia.json), which takes a logind sleep inhibitor and locks before
    # the system sleeps — so no separate lock service is needed here.
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
    };
  };
}