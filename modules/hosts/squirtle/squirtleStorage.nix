{ self, inputs, ... }: {
  flake.nixosModules.squirtleStorage = { lib, pkgs, config, ... }: {
    # ┌─────────────────────────────────────────────────────────────┐
    # │ squirtle storage layout                                     │
    # │  /mnt/disk2, /mnt/disk3  bulk data (btrfs, mergerfs union)  │
    # │  /mnt/parity             dedicated SnapRAID parity (CMR)    │
    # │  /mnt/cache              NVMe partition: vital data interim │
    # │  /mnt/storage            mergerfs union of data disks       │
    # │  SnapRAID: daily sync+scrub timer, Discord on failure       │
    # └─────────────────────────────────────────────────────────────┘

    # ──── Individual drives ────
    # disk2 = IronWolf ST4000VN006 (CMR)
    # disk3 = Barracuda ST4000DM004 (SMR — write-once media only;
    # kept OFF parity where SMR's rewrite penalty bites)
    fileSystems."/mnt/disk2" = {
      device = "/dev/disk/by-uuid/ad12db81-67fe-45d5-91af-7378c47327f3";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
    fileSystems."/mnt/disk3" = {
      device = "/dev/disk/by-uuid/3ea864be-f401-4e31-9584-82cca5329e1e";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
    # Dedicated parity drive (IronWolf, CMR) — snapraid parity is
    # rewrite-heavy, the one workload SMR must not own
    fileSystems."/mnt/parity" = {
      device = "/dev/disk/by-uuid/a499c65b-cac8-473b-804c-9a2c307fb71e";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
    fileSystems."/mnt/cache" = {
      device = "/dev/disk/by-uuid/f72e39fa-3225-4c84-987e-40f44fe7f8bf";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };

    # ──── MergerFS pool ────
    # HDD-only union — flash tiers excluded
    # mfs policy balances writes across both data disks by free space
    fileSystems."/mnt/storage" = {
      device = "/mnt/disk2:/mnt/disk3";
      fsType = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        "cache.files=off"
        "dropcacheonclose=true"
        "category.create=mfs"
        "moveonenospc=true"
      ];
      noCheck = true;
    };

    # ──── Directory ownership ────
    # Pre-create required directories with correct ownership
    systemd.tmpfiles.rules = [
      "d /mnt/cache/downloads  0775 qbittorrent media -"
      "d /mnt/cache/incomplete 0775 qbittorrent media -"
      "d /mnt/storage/tv       0775 sonarr       media -"
      "d /mnt/storage/movies   0775 radarr        media -"
      "d /mnt/storage/backups 0775 phaedrus users -"
    ];

    # ──── SnapRAID ────
    # Content files on root + both data disks; the parity drive
    # intentionally carries none. /downloads excluded: transient
    # torrent payload, no parity value.
    environment.etc."snapraid.conf".text = ''
      parity /mnt/parity/snapraid.parity
      content /var/snapraid.content
      content /mnt/disk2/.snapraid.content
      content /mnt/disk3/.snapraid.content
      data d2 /mnt/disk2
      data d3 /mnt/disk3
      exclude *.tmp
      exclude *.bak
      exclude /tmp/
      exclude /downloads/
    '';

    environment.systemPackages = with pkgs; [
      snapraid
      mergerfs
    ];

    # WHY: sync failure must be loud — this pool ran parity-less for
    # its entire life without anyone noticing, and stale parity is the
    # Tang incident's storage twin (silent until the day it's needed).
    systemd.services.snapraid-sync = {
      description = "SnapRAID sync and scrub";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "snapraid-sync" ''
          ${pkgs.snapraid}/bin/snapraid sync \
            && ${pkgs.snapraid}/bin/snapraid scrub -p 10 -o 30 \
            || ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "🚨 **SnapRAID sync/scrub FAILED on squirtle**"}'
        '';
      };
    };
    systemd.timers.snapraid-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
      OnCalendar = "00:00";   # after backup.timer (23:00) — order is load-bearing
        Persistent = true;
      };
    };
  };
}