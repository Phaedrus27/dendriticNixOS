{ self, inputs, ... }: {
  flake.nixosConfigurations.charizard = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.charizardConfiguration ];
  };

  flake.nixosModules.charizardConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.charizardHardware
      self.nixosModules.workstation
      self.nixosModules.charizardSecurity
      self.nixosModules.gaming
      self.nixosModules.syncthing
      self.nixosModules.chromium
      self.nixosModules.keychron
      self.nixosModules.niriSession
      self.nixosModules.charizardNiri
      self.nixosModules.base
      self.nixosModules.editingApps
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

    services.tailscale.useRoutingFeatures = "none";

    services.tuned.enable = true;
    services.openssh.enable = true;

    system.stateVersion = "25.11";

    # nixos-raspberrypi's binary cache, registered at the daemon level: flake
    # nixConfig can't add substituters for non-trusted users, and charizard is
    # the fleet's aarch64 image builder (pidgey now; bulbasaur/abra onboarding
    # later). substituters merges with the module default, so cache.nixos.org
    # stays first.
    nix.settings = {
      substituters = [ "https://nixos-raspberrypi.cachix.org" ];
      trusted-public-keys = [
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      ];
    };
  };
}