{ self, inputs, ... }: {
  flake.nixosModules.mewConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.mewHardware
      self.nixosModules.mewNiri
      self.nixosModules.mewSecurity
      self.nixosModules.syncthing
      self.nixosModules.obsidian
      self.nixosModules.environment
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking = {
      hostName = "mew";
      interfaces.wlp1s0.ipv4.addresses = [{
        address = "192.168.1.151";
        prefixLength = 24;
      }];
      defaultGateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };

    time.timeZone = "Europe/Brussels";
    i18n.defaultLocale = "en_GB.UTF-8";

    services.xserver.xkb = {
      layout = "fr";
      variant = "afnor";
    };
    console.keyMap = "fr";

    services.tuned.enable = true;
    services.upower.enable = true;
    services.printing.enable = true;

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    users.users.phaedrus = {
      isNormalUser = true;
      description = "phaedrus";
      extraGroups = [ "networkmanager" "wheel" ];
    };

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      git
      vscodium
      vesktop
      vlc
      pywalfox-native
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    system.stateVersion = "25.11";
  };
}