{ self, inputs, ... }: {
  flake.nixosModules.squirtleStorage = { lib, pkgs, ... }: {
    # Mount individual drives
    fileSystems."/mnt/disk1" = {
      device = "/dev/disk/by-uuid/e7be5a5a-3e5c-4227-8016-5655781c4db1";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
    fileSystems."/mnt/disk2" = {
      device = "/dev/disk/by-uuid/ad12db81-67fe-45d5-91af-7378c47327f3";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
    fileSystems."/mnt/cache" = {
      device = "/dev/disk/by-uuid/f72e39fa-3225-4c84-987e-40f44fe7f8bf";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
    # HDD-only MergerFS pool — SSD excluded
    # mfs policy balances writes across both HDDs by free space
    # SSD handles downloads separately via qBittorrent
    fileSystems."/mnt/storage" = {
      device = "/mnt/disk1:/mnt/disk2";
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
    # Pre-create required directories with correct ownership
    systemd.tmpfiles.rules = [
      "d /mnt/cache/downloads  0775 qbittorrent media -"
      "d /mnt/cache/incomplete 0775 qbittorrent media -"
      "d /mnt/storage/tv       0775 sonarr       media -"
      "d /mnt/storage/movies   0775 radarr        media -"
      "d /mnt/storage/backups 0775 phaedrus users -"
    ];
    # SnapRAID config
    # Parity on disk1 is intentional — only 2 data drives currently.
    # When a 3rd drive is added, move parity to a dedicated parity drive
    # and add: data d3 /mnt/disk3
    environment.etc."snapraid.conf".text = ''
      parity /mnt/disk1/.snapraid.parity
      content /var/snapraid.content
      content /mnt/disk1/.snapraid.content
      content /mnt/disk2/.snapraid.content
      data d1 /mnt/disk1
      data d2 /mnt/disk2
      exclude *.tmp
      exclude *.bak
      exclude /tmp/
      exclude /downloads/
    '';
    environment.systemPackages = with pkgs; [
      snapraid
      mergerfs
    ];
    # SnapRAID sync + scrub — disabled until dedicated parity drive is added
    systemd.services.snapraid-sync = {
      description = "SnapRAID sync and scrub";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "snapraid-sync" ''
          ${pkgs.snapraid}/bin/snapraid sync
          ${pkgs.snapraid}/bin/snapraid scrub -p 10 -o 30
        '';
      };
    };
    systemd.timers.snapraid-sync = {
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}