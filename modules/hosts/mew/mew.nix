{ self, inputs, ... }: {
  flake.nixosConfigurations.mew = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.mewConfiguration ];
  };

  flake.nixosModules.mewConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.mewHardware
      self.nixosModules.mewNiri
      self.nixosModules.mewSecurity
      self.nixosModules.syncthing
      self.nixosModules.workstation     
      self.nixosModules.niriSession
      self.nixosModules.base
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # Roaming laptop: accepts pidgey's 192.168.1.0/24 route so .home records
    # (kanto LAN IPs) resolve AND route when off-LAN. Cost: on home WiFi,
    # LAN traffic may hairpin via pidgey — measured <date>, result <direct|hairpin>.
    services.tailscale.useRoutingFeatures = "client";

    networking.hostName = "mew";

    # ── Host-specific hardware ──────────────────────────────────────────
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;

    # Deliberately off: tuned conflicted with TLP on this machine
    # Power management handled by the Framework defaults.
    # services.tuned.enable = true;

    services.openssh.enable = true;

    system.stateVersion = "25.11";
  };
}