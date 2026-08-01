{ self, inputs, ... }: {
  flake.nixosModules.backup = { config, pkgs, ... }: {

    environment.systemPackages = [ pkgs.restic ];

    # Secrets this module consumes — declared here so the module is
    # self-contained: any host importing it needs these keys in its own
    # defaultSopsFile. (discord_webhook is also declared by monitoring;
    # identical declarations merge to one secret.)
    sops.secrets.restic_password = { };
    sops.secrets.discord_webhook = { };

    # Nightly local backup to HDD array
    systemd.services.backup = {
      description = "Restic backup to local HDD array";
      serviceConfig = {
        Type = "oneshot";
        CacheDirectory = "restic";
        ExecStart = pkgs.writeShellScript "backup" ''
          export RESTIC_PASSWORD=$(cat ${config.sops.secrets.restic_password.path})
          ${pkgs.restic}/bin/restic \
            -r /mnt/storage/backups \
            backup \
            /mnt/cache/paperless \
            /mnt/cache/syncthing/obsidian \
            /mnt/cache/phone-backup \
            && ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "✅ **Backup completed on squirtle**: paperless, obsidian, and zubat backed up successfully."}' \
            || ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "🚨 **Backup FAILED on squirtle**: check restic logs immediately."}'
        '';
      };
    };
    systemd.timers.backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # WHY: fires before snapraid's midnight sync so each night's parity
        # pass covers that night's fresh backup data — same-time firing had
        # restic writing into the pool mid-parity-computation.
        OnCalendar = "23:00";
        Persistent = true;
      };
    };

    # ──── Retention ────
    # WHY: without forget/prune the repo grows forever — restic keeps every
    # blob Seedvault ever rotated out, so the phone's ~5GB folder compounds
    # nightly even though its live size is flat. Weekly is enough; prune
    # rewrites pack files and is the heaviest thing that touches the array.
    systemd.services.backup-prune = {
      description = "Restic retention prune on local HDD array";
      serviceConfig = {
        Type = "oneshot";
        CacheDirectory = "restic";
        ExecStart = pkgs.writeShellScript "backup-prune" ''
          export RESTIC_PASSWORD=$(cat ${config.sops.secrets.restic_password.path})
          ${pkgs.restic}/bin/restic \
            -r /mnt/storage/backups \
            forget --prune \
            --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
            && ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "✅ **Restic prune completed on squirtle**"}' \
            || ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "🚨 **Restic prune FAILED on squirtle**: check logs."}'
        '';
      };
    };
    systemd.timers.backup-prune = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # WHY: 22:00 Sunday, an hour ahead of backup.timer — prune rewrites
        # pack files, so it must land inside the same night the 23:00 backup
        # and 00:00 snapraid sync seal, not orphaned a day away from parity.
        OnCalendar = "Sun 22:00";
        Persistent = true;
      };
    };

    # Manual backup to charizard — trigger with: sudo systemctl start backup-charizard
    systemd.services.backup-charizard = {
      description = "Restic backup to charizard";
      serviceConfig = {
        Type = "oneshot";
        CacheDirectory = "restic-charizard";
        ExecStart = pkgs.writeShellScript "backup-charizard" ''
          export RESTIC_PASSWORD=$(cat ${config.sops.secrets.restic_password.path})
          ${pkgs.restic}/bin/restic \
            -r sftp:phaedrus@100.117.81.78:/mnt/data/backups/squirtle \
            -o sftp.command="${pkgs.openssh}/bin/ssh -i /etc/ssh/backup_ed25519 -l phaedrus 100.117.81.78 -s sftp" \
            backup \
            /mnt/cache/paperless \
            /mnt/cache/syncthing/obsidian \
            /mnt/cache/phone-backup \
            && ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "✅ **Charizard backup completed**: paperless, obsidian, and zubat backed up to charizard."}' \
            || ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "🚨 **Charizard backup FAILED**: check restic logs."}'
        '';
      };
    };

  };
}