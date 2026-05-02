{ self, inputs, ... }: {
  flake.nixosModules.yubikey = { pkgs, ... }: {

    # PC/SC daemon for smart card communication
    services.pcscd.enable = true;

    # GPG agent with pinentry for YubiKey PIN prompts
    programs.gnupg.agent = {
      enable = true;
      enable SSHSupport = true;
      pinentryPackage = pkgs.pinentry-gtk2;
    };

    # udev rules so your user can access the YubiKey without root
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # Useful YubiKey management tools
    environment.systemPackages = with pkgs; [
      yubikey-manager
      yubikey-personalization
      gnupg
      age
      sops
      age-plugin-yubikey
    ];
  };
}