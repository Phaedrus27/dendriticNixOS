{ self, inputs, ... }: {
  flake.nixosModules.backup = { config, pkgs, ... }: {

    environment.systemPackages = [ pkgs.restic ];

    sops.secrets.restic_password = {};

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
            && ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "✅ **Backup completed on squirtle**: paperless and obsidian backed up successfully."}' \
            || ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "🚨 **Backup FAILED on squirtle**: check restic logs immediately."}'
        '';
      };
    };
    systemd.timers.backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
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
            && ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "✅ **Charizard backup completed**: paperless and obsidian backed up to charizard."}' \
            || ${pkgs.curl}/bin/curl -s -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
              -H "Content-Type: application/json" \
              -d '{"content": "🚨 **Charizard backup FAILED**: check restic logs."}'
        '';
      };
    };

  };
}