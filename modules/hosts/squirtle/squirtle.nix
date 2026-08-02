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
      self.nixosModules.scanServer
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

      # ──── Firewall ────
      firewall = {
        enable = true;
        # Jellyfin HTTP — LAN media clients (Shield, charizard). Swept out
        # during the DNS-demotion hardening pass; do not remove again.
        allowedTCPPorts = [ 8096 ];
      };
    };

      # ──── Monitoring inventory ────
      dendriticNixOS.monitoring = {
        watchedServices = [
          # existing long-running roster, unchanged
        ];

        # Oneshots: OnFailure-hooked and deadmanned, never polled — a completed
        # oneshot reads as inactive, so polling would alert DOWN forever.
        # maxHours sits just past one scheduling interval, so a single skipped
        # run is the signal rather than a sustained outage.
        watchedJobs = [
          { unit = "backup";               maxHours = 30; }   # nightly 23:00
          { unit = "snapraid-sync";        maxHours = 30; }   # nightly 00:00
          { unit = "backup-prune";         maxHours = 200; }  # Sun 22:00
          { unit = "disk-monitor";         maxHours = 30; }   # daily 09:00
          { unit = "disk-space-monitor";   maxHours = 3; }    # hourly
          { unit = "failed-units-monitor"; maxHours = 1; }    # */5 — was found
                                                            # sitting failed by hand
        ];

        # Service liveness is not evidence that data is arriving: the zubat
        # folder-ID mismatch kept syncthing active and the sink at 4K for weeks.
        # Only newest-mtime can see that class of failure.
        watchedPaths = [
          { path = "/mnt/cache/phone-backup";       maxHours = 96; }  # Seedvault runs on idle+charge
          { path = "/mnt/cache/syncthing/obsidian"; maxHours = 336; } # two weeks of no notes is plausible
          { path = "/mnt/storage/backups";          maxHours = 30; }  # restic writes nightly
        ];

        # Serial-suffixed by-id throughout: parity and disk2 are the same
        # IronWolf model, so anything less specific can swap them after a
        # controller renumber and silently monitor the wrong drive.
        watchedDisks = [
          "/dev/disk/by-id/ata-ST4000VN006-3CW104_ZW63JHDE"              # parity  (IronWolf)
          "/dev/disk/by-id/ata-ST4000VN006-3CW104_ZW63HHNT"              # disk2   (IronWolf)
          "/dev/disk/by-id/ata-ST4000DM004-2CV104_WFN41F62"              # disk3   (Barracuda)
          "/dev/disk/by-id/ata-Samsung_SSD_860_EVO_2TB_S3YVNX0N700137K"  # scratch (860 EVO)
        ];

        # Kernel name, not by-id: udev emits a duplicate by-id for this drive
        # (…_50026B7283698D7A and …_1) and which one carries the suffix is not
        # stable across boots. Only one NVMe is present, so nvme0n1 cannot be
        # ambiguous.
        watchedNvme = [ "/dev/nvme0n1" ];

        watchedFilesystems = [
          # 128G post-resize; one system closure is ~8G, so 15% free is roughly
          # two rebuilds of runway.
          { mount = "/";            high = 85; low = 75; }
          # 95G post-resize, and a ~5GB non-dedupable Seedvault set can move this
          # several points between hourly checks — the old 90/85 left only ~9G.
          { mount = "/mnt/cache";   high = 75; low = 65; }
          # Earlier than the rest: pruning finished seeds here is manual.
          { mount = "/mnt/scratch"; high = 80; low = 70; }
          # mergerfs pool — watched alongside its branches, since a dropped branch
          # shrinks the pool rather than failing it.
          { mount = "/mnt/storage"; high = 85; low = 75; }
          { mount = "/mnt/disk2";   high = 90; low = 80; }
          { mount = "/mnt/disk3";   high = 90; low = 80; }
          # Parity must always have room to grow with the largest data disk.
          { mount = "/mnt/parity";  high = 90; low = 80; }
        ];

        # The Era-case drives run on cables with no airflow gaps; the Barracuda
        # already reached 47°C under evacuation load.
        tempHigh = 50;
        tempLow  = 45;
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