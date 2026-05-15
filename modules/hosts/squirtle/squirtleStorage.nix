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

    # mergerfs pool — cache first, then HDDs
    fileSystems."/mnt/storage" = {
      device = "/mnt/cache:/mnt/disk1:/mnt/disk2";
      fsType = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        "cache.files=off"
        "dropcacheonclose=true"
        "category.create=ff"
        "moveonenospc=true"
        "nofail"
      ];
    };

    # SnapRAID config
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
    '';

    environment.systemPackages = with pkgs; [
      snapraid
      mergerfs
    ];

    # Cache mover — moves cold files from cache to HDDs nightly
    systemd.services.cache-mover = {
      description = "Move cold files from cache to HDD pool";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "cache-mover" ''
          find /mnt/cache -mindepth 1 -maxdepth 10 -type f \
            ! -name ".snapraid*" \
            -atime +7 \
            | while IFS= read -r f; do
              rel="''${f#/mnt/cache}"
              dest="/mnt/disk1''${rel}"
              mkdir -p "$(dirname "$dest")"
              ${pkgs.rsync}/bin/rsync -a --remove-source-files "$f" "$dest" && \
                find "$(dirname "$f")" -mindepth 1 -empty -delete
            done
        '';
      };
    };

    systemd.timers.cache-mover = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # SnapRAID sync
    systemd.services.snapraid-sync = {
      description = "SnapRAID sync";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.snapraid}/bin/snapraid sync";
      };
    };

    systemd.timers.snapraid-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}