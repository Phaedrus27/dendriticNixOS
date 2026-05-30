{ self, inputs, ... }: {
  flake.nixosModules.charizardConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.charizardHardware
      self.nixosModules.charizardNiri
      self.nixosModules.charizardSecurity
      self.nixosModules.gaming
      self.nixosModules.syncthing
      self.nixosModules.obsidian
      self.nixosModules.chromium
      self.nixosModules.keychron
      self.nixosModules.environment
      self.nixosModules.tailscale
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking = {
      hostName = "charizard";
      interfaces.enp7s0.ipv4.addresses = [{
        address = "192.168.1.6";
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

    services.libinput.enable = true;
    services.tuned.enable = true;
    services.upower.enable = true;
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint        # generic, covers many printers
        hplip             # HP printers
        brlaser           # Brother laser printers
        epson-escpr       # Epson
        samsung-unified-linux-driver  # Samsung
      ];
    };

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

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

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    system.stateVersion = "25.11";
  };
}