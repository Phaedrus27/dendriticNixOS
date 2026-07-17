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

    # WHY: interface names derive from PCI position; adding the ASM1166
    # SATA card renumbered the bus and enp3s0 became enp4s0, silently
    # killing the static IP and the GRO unit (2026-07-16 boot report).
    # Pin the NIC to a topology-independent name by permanent MAC so
    # future slot/card changes can't repeat this.
    systemd.network.links."10-lan" = {
      matchConfig.PermanentMACAddress = "60:cf:84:e9:e2:ab";
      linkConfig.Name = "lan0";
    };

    networking = {
      hostName = "squirtle";
      interfaces.lan0.ipv4.addresses = [{
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
    # Drives are watched by-id (serial-derived): immune to the sdX
    # enumeration shuffle that five drives on two controllers guarantee.
    dendriticNixOS.monitoring = {
      discordUsername = "Squirtle";
      watchedDisks = [
        "/dev/disk/by-id/ata-ST4000VN006-3CW104_ZW63HHNT"   # disk2 (IronWolf, data)
        "/dev/disk/by-id/ata-ST4000DM004-2CV104_WFN41F62"   # disk3 (Barracuda, data)
        "/dev/disk/by-id/ata-ST4000VN006-3CW104_ZW63JHDE"   # parity (IronWolf)
      ];
      watchedNvme = [ "/dev/nvme0n1" ];
      watchedFilesystems = [
        { mount = "/";            high = 85; low = 75; }
        { mount = "/mnt/cache";   high = 90; low = 85; }
        { mount = "/mnt/disk2";   high = 90; low = 85; }
        { mount = "/mnt/disk3";   high = 90; low = 85; }
        { mount = "/mnt/parity";  high = 95; low = 90; }
        { mount = "/mnt/storage"; high = 90; low = 85; }
      ];
    };

    sops.secrets.tailscale_authkey = { };
    dendriticNixOS.tailscale.authKeyFile = config.sops.secrets.tailscale_authkey.path;

    systemd.services.ethtool-udp-gro = {
      description = "Enable UDP GRO forwarding on lan0";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -K lan0 rx-udp-gro-forwarding on rx-gro-list off";
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
      tmux
    ];

    # Sudo requires the account password (set 2026-07-04, while sudo was
    # still free — order matters: flipping this first would have removed
    # the only escalation path). Squirtle holds the fleet's sops age key;
    # passwordless escalation made any code running as phaedrus
    # root-equivalent. SSH stays key-only (FIDO2), so the password's sole
    # exposure is this prompt. Root has no password: su is dead by design.
    security.sudo.wheelNeedsPassword = true;

    system.stateVersion = "25.11";
  };
}