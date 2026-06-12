{ self, inputs, ... }: {
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
      self.nixosModules.tailscale
      self.nixosModules.base
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

    services.tuned.enable = true;

    services.openssh.enable = true;

    system.stateVersion = "25.11";
  };
}