{ self, inputs, ... }: {
  flake.nixosModules.backup = { config, pkgs, lib, ... }:
    let
      # ──── Job builder ────
      # All three restic jobs share one wrapper. Behaviour it guarantees:
      #   * RESTIC_CACHE_DIR is set          — restic 0.19 aborts without a cache
      #   * password passed by FILE           — keeps it out of /proc/PID/environ
      #   * exit code is restic's, not curl's — so systemd sees real failures
      #   * alert carries the actual error    — not "check the logs"
      mkResticJob = { name, cache, okMessage, args }: pkgs.writeShellScript name ''
        # WHY no `set -e`: a non-zero restic must reach the notify branch below
        # rather than killing the script before anything is reported.
        set -uo pipefail

        export RESTIC_PASSWORD_FILE=${config.sops.secrets.restic_password.path}

        # WHY: restic resolves its cache from RESTIC_CACHE_DIR / XDG_CACHE_HOME /
        # HOME only. systemd's CacheDirectory= exports $CACHE_DIRECTORY, which
        # restic ignores, and a system unit has no $HOME — so restic 0.19 finds
        # no cache and exits before the parent-snapshot lookup. The fallback
        # covers hand-invocation of this script outside its unit.
        export RESTIC_CACHE_DIR="''${CACHE_DIRECTORY:-/var/cache/${cache}}"

        # WHY jq: restic error text contains quotes, backslashes and newlines
        # that break raw interpolation into JSON, and Discord drops malformed
        # payloads silently — a broken alert is indistinguishable from no fault.
        # WHY `|| true`: a webhook outage must not become the job's verdict.
        notify() {
          ${pkgs.curl}/bin/curl -sS -X POST "$(cat ${config.sops.secrets.discord_webhook.path})" \
            -H "Content-Type: application/json" \
            --data-raw "$(${pkgs.jq}/bin/jq -nc --arg c "$1" '{content: $c}')" || true
        }

        # WHY tee + PIPESTATUS rather than out=$(...): a multi-hour prune must
        # stream to the journal as it runs, while still leaving the tail
        # available for the alert body.
        log=$(mktemp)
        trap 'rm -f "$log"' EXIT

        ${pkgs.restic}/bin/restic ${lib.concatStringsSep " " args} 2>&1 | tee "$log"
        rc=''${PIPESTATUS[0]}

        if [ "$rc" -eq 0 ]; then
          notify "${okMessage}"
        else
          notify "🚨 **${name} FAILED on ${config.networking.hostName}** (exit $rc): $(tail -5 "$log" | tr '\n' ' ')"
        fi

        exit "$rc"
      '';

      localRepo = [ "-r" "/mnt/storage/backups" ];

      sources = [
        "/mnt/cache/paperless"
        "/mnt/cache/syncthing/obsidian"
        "/mnt/cache/phone-backup"
      ];
    in
    {
      environment.systemPackages = [ pkgs.restic ];

      # Secrets this module consumes — declared here so the module is
      # self-contained: any host importing it needs these keys in its own
      # defaultSopsFile. (discord_webhook is also declared by monitoring;
      # identical declarations merge to one secret.)
      sops.secrets.restic_password = { };
      sops.secrets.discord_webhook = { };

      # ──── Nightly local backup to HDD array ────
      systemd.services.backup = {
        description = "Restic backup to local HDD array";
        # WHY unitConfig: RequiresMountsFor is a [Unit] key. Placed in
        # serviceConfig it parses, is discarded with a warning only visible at
        # activation, and the protection silently does not exist.
        # WHY at all: /mnt/storage is mergerfs and /mnt/cache a separate NVMe
        # partition — without this the unit can start against an unmounted pool
        # and fail fast in a way indistinguishable from a repo fault.
        unitConfig.RequiresMountsFor = [ "/mnt/storage" "/mnt/cache" ];
        serviceConfig = {
          Type = "oneshot";
          CacheDirectory = "restic";
          ExecStart = mkResticJob {
            name = "backup";
            cache = "restic";
            okMessage = "✅ **Backup completed on ${config.networking.hostName}**: paperless, obsidian, and zubat.";
            # WHY --retry-lock: prune holds an exclusive lock from 22:00 Sunday
            # and rewrites pack files; the first run over an unpruned repo can
            # still be working at 23:00. Waiting beats a spurious failure.
            args = localRepo ++ [ "backup" "--retry-lock" "60m" ] ++ sources;
          };
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
        unitConfig.RequiresMountsFor = [ "/mnt/storage" ];
        serviceConfig = {
          Type = "oneshot";
          CacheDirectory = "restic";
          ExecStart = mkResticJob {
            name = "backup-prune";
            cache = "restic";
            okMessage = "✅ **Restic prune completed on ${config.networking.hostName}**";
            args = localRepo ++ [
              "forget"
              "--prune"
              "--retry-lock"
              "30m"
              "--keep-daily"
              "7"
              "--keep-weekly"
              "4"
              "--keep-monthly"
              "6"
            ];
          };
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

      # ──── Manual backup to charizard ────
      # Trigger with: sudo systemctl start backup-charizard
      # WHY no timer: the destination /mnt/data was the 2TB SSD now serving as
      # squirtle's scratch tier, so this repo does not currently exist. The unit
      # is kept declared so the off-machine path is one repoint away once an
      # offsite target is chosen; it will fail loudly until then.
      systemd.services.backup-charizard = {
        description = "Restic backup to charizard";
        unitConfig.RequiresMountsFor = [ "/mnt/cache" ];
        serviceConfig = {
          Type = "oneshot";
          CacheDirectory = "restic-charizard";
          ExecStart = mkResticJob {
            name = "backup-charizard";
            cache = "restic-charizard";
            okMessage = "✅ **Charizard backup completed**: paperless, obsidian, and zubat.";
            args = [
              "-r"
              "sftp:phaedrus@100.117.81.78:/mnt/data/backups/squirtle"
              # WHY explicit sftp.command: the private key is hand-placed at
              # /etc/ssh/backup_ed25519, outside both the flake and sops — a
              # rebuilt-from-scratch host comes up looking configured and unable
              # to connect.
              "-o"
              ''sftp.command="${pkgs.openssh}/bin/ssh -i /etc/ssh/backup_ed25519 -l phaedrus 100.117.81.78 -s sftp"''
              "backup"
            ] ++ sources;
          };
        };
      };

    };
}