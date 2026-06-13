{ self, inputs, ... }: {
  flake.nixosModules.squirtleConfiguration = { pkgs, lib, config, ... }: {
    imports = [
      self.nixosModules.squirtleHardware
      self.nixosModules.squirtleStorage
      self.nixosModules.tailscale
      self.nixosModules.sops
      self.nixosModules.squirtleSops
      self.nixosModules.samba
      self.nixosModules.mediaServer
      self.nixosModules.syncthing
      self.nixosModules.paperless
      self.nixosModules.backup
      self.nixosModules.base
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    users.users.phaedrus = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      # sk-keys are authorized fleet-wide via base.nix — nothing host-specific here now.
    };

    networking = {
      hostName = "squirtle";
      interfaces.enp3s0.ipv4.addresses = [{
        address = "192.168.1.7";
        prefixLength = 24;
      }];
      defaultGateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
      networkmanager.enable = true;
      firewall.enable = true;
    };

    sops.secrets.tailscale_authkey = { };
    dendriticNixOS.tailscale.authKeyFile = config.sops.secrets.tailscale_authkey.path;

    systemd.services.ethtool-udp-gro = {
      description = "Enable UDP GRO forwarding on enp3s0";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -K enp3s0 rx-udp-gro-forwarding on rx-gro-list off";
      };
    };

    # Squirtle acts as a subnet router, advertising the local network to the tailnet
    services.tailscale.useRoutingFeatures = "server";

    services.openssh.enable = true;

    environment.systemPackages = with pkgs; [
      git
      htop
      wget
      curl
      smartmontools
      lsof
      ncdu
    ];

    security.sudo.wheelNeedsPassword = false;

    system.stateVersion = "25.11";
  };
}