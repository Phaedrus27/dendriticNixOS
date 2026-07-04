{ self, inputs, ... }: {
  flake.nixosConfigurations.squirtle = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.squirtleConfiguration ];
  };

  flake.nixosModules.squirtleConfiguration = { pkgs, lib, config, ... }: {
    imports = [
      self.nixosModules.squirtleHardware
      self.nixosModules.squirtleStorage
      self.nixosModules.sops
      self.nixosModules.samba
      self.nixosModules.mediaServer
      self.nixosModules.syncthing
      self.nixosModules.paperless
      self.nixosModules.backup
      self.nixosModules.base
      self.nixosModules.monitoring
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
      # Pi-hole on pidgey, matching the fleet convention (see charizard).
      # Normally shadowed: tailscaled's MagicDNS override (accept-dns
      # defaults to true) routes host DNS to pidgey via 100.100.100.100
      # anyway — this static entry is the bootstrap/fallback path for when
      # tailscaled is down. qBittorrent is unaffected either way: its DNS
      # is confined to the VPN netns resolver (see seedbox/qbittorrent.nix).
      nameservers = [ "192.168.1.16" ];
      networkmanager.enable = true;
      firewall.enable = true;
    };

    # ──── Monitoring inventory: what this host watches ────
    # Service registrations come from the role modules (arr, seedbox, …);
    # disks and filesystems are host hardware, so they live here.
    # NOTE: /dev/sdX names assume stable enumeration — verify against lsblk.
    dendriticNixOS.monitoring = {
      discordUsername = "Squirtle";
      watchedDisks = [ "/dev/sda" "/dev/sdb" ];
      watchedNvme = [ "/dev/nvme0n1" ];
      watchedFilesystems = [
        { mount = "/";            high = 85; low = 75; }
        { mount = "/mnt/cache";   high = 90; low = 85; }
        { mount = "/mnt/disk1";   high = 90; low = 85; }
        { mount = "/mnt/disk2";   high = 90; low = 85; }
        { mount = "/mnt/storage"; high = 90; low = 85; }
      ];
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