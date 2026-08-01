{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, lib, ... }:
    # ──────────────────────────────────────────────────────────────
    #  Fleet monitoring — Discord alerting over a shared webhook.
    #
    #  Rosters (hosts register their own):
    #    watchedServices  long-running units — OnFailure + up/down poll
    #    watchedJobs      oneshot units      — OnFailure + staleness deadman
    #    watchedPaths     data trees         — mtime freshness deadman
    #    watchedDisks     SATA/SAS by-id     — health, attrs, wear, temp
    #    watchedNvme      NVMe by-id         — health, media errors, wear, temp
    #    watchedFilesystems  mountpoints     — mount presence + capacity
    #
    #  Monitors, in file order:
    #    failed-units-monitor   */5      newly failed units the rosters miss
    #    boot-notify            at boot  real boots only, clears stale state
    #    notify-failure@        event    instant crash alert, rate limited
    #    service-monitor        */15     up/down transitions + recovery
    #    freshness-monitor      hourly   jobs and paths that stopped happening
    #    disk-monitor           daily    SMART health, attrs, wear, temperature
    #    disk-space-monitor     hourly   mount presence + capacity
    #    heartbeat              weekly   proves the alert path itself is alive
    # ──────────────────────────────────────────────────────────────
    let
      cfg = config.dendriticNixOS.monitoring;

      watched = cfg.watchedServices;
      jobs    = cfg.watchedJobs;
      paths   = cfg.watchedPaths;
      disks   = cfg.watchedDisks;
      nvmes   = cfg.watchedNvme;
      fses    = cfg.watchedFilesystems;

      # Oneshots need the OnFailure hook but must never reach the poller:
      # a successfully completed oneshot reads as inactive, so polling it
      # would alert DOWN every 15 minutes forever.
      jobUnits    = map (j: j.unit) jobs;
      hookedUnits = watched ++ jobUnits;

      # The generic watcher exists to catch what the rosters miss, so
      # anything already carrying an OnFailure hook is filtered out of it.
      excludedUnits = map (u: "${u}.service") hookedUnits;

      # JSON-safe Discord notify, shared by all scripts via sourcing.
      # USERNAME stamps a per-host sender name into every message, so one
      # shared webhook still surfaces each host under its own identity.
      shellLib = ''
        HOST="${config.networking.hostName}"
        USERNAME="${cfg.discordUsername}"
        WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})

        # --fail is load-bearing: without it curl exits 0 on 4xx/5xx, so a
        # revoked webhook or a 429 would be indistinguishable from delivery.
        notify() {
          ${pkgs.jq}/bin/jq -n --arg c "$1" --arg u "$USERNAME" \
              '{content: $c, username: $u}' \
            | ${pkgs.curl}/bin/curl -sS --fail --max-time 15 \
                --retry 3 --retry-delay 5 --retry-connrefused \
                -X POST "$WEBHOOK" -H "Content-Type: application/json" -d @-
        }

        # Every parsed metric passes through here — an unreadable value must
        # not fall back to 0 and get reported as healthy.
        is_num() { [ -n "$1" ] && [ -z "$(echo "$1" | tr -d '0-9')" ]; }

        # Hysteresis helper: fire once per state change, not once per run.
        # $1 state file, $2 new state, $3 message (empty = stay silent)
        transition() {
          SF="$1"; NEW="$2"; MSG="$3"
          OLD=$(cat "$SF" 2>/dev/null || echo "ok")
          if [ "$NEW" != "$OLD" ]; then
            [ -n "$MSG" ] && notify "$MSG"
            echo "$NEW" > "$SF"
          fi
        }
      '';

      # Shell lines that invoke a checker over a registered inventory list.
      diskCalls = lib.concatMapStrings (d: "check_disk ${d}\n") disks;
      nvmeCalls = lib.concatMapStrings (n: "check_nvme ${n}\n") nvmes;
      fsCalls   = lib.concatMapStrings
        (f: "check_fs ${f.mount} ${toString f.high} ${toString f.low}\n") fses;
      jobCalls  = lib.concatMapStrings
        (j: "check_job ${j.unit} ${toString j.maxHours}\n") jobs;
      pathCalls = lib.concatMapStrings
        (p: "check_path ${lib.escapeShellArg p.path} ${toString p.maxHours}\n") paths;
    in {
      # Stable identity in case a host and one of its role modules both pull
      # monitoring into the same evaluation — the module system dedupes on key.
      key = "dendriticNixOS/monitoring";

      # ──── Options: hosts register their own inventory ────
      options.dendriticNixOS.monitoring = {
        watchedServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Long-running services: instant OnFailure alerts plus 15-min
            up/down polling. Bare unit names, no .service suffix. Oneshot
            units belong in watchedJobs instead.
          '';
        };

        watchedJobs = lib.mkOption {
          default = [ ];
          description = ''
            Oneshot/timer-driven units: OnFailure alerts plus a staleness
            deadman. A unit that silently stops being scheduled is not a
            failed unit, so nothing else in this module can see it.
          '';
          type = lib.types.listOf (lib.types.submodule {
            options = {
              unit = lib.mkOption {
                type = lib.types.str;
                description = "Bare unit name, no .service suffix.";
              };
              maxHours = lib.mkOption {
                type = lib.types.ints.positive;
                description = "Alert if the last run is older than this.";
              };
            };
          });
        };

        watchedPaths = lib.mkOption {
          default = [ ];
          description = ''
            Data trees that must keep receiving writes. Liveness of the
            producing service is not evidence that data is arriving — a
            Syncthing folder-ID mismatch keeps the unit active and the
            folder empty.
          '';
          type = lib.types.listOf (lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "Directory whose newest file mtime is checked.";
              };
              maxHours = lib.mkOption {
                type = lib.types.ints.positive;
                description = "Alert if nothing under path is newer than this.";
              };
            };
          });
        };

        # Per-host Discord sender name. Defaults to the hostname so a shared
        # webhook still distinguishes hosts; override for a prettier label.
        discordUsername = lib.mkOption {
          type = lib.types.str;
          default = config.networking.hostName;
          description = "Username stamped on this host's Discord notifications.";
        };

        watchedDisks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "/dev/disk/by-id/ata-ST4000VN008_ZW63HHNT" ];
          description = "SATA/SAS by-id paths to SMART-check (health, attrs, wear, temperature).";
        };

        watchedNvme = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "/dev/nvme0n1" ];
          description = "NVMe device paths to SMART-check (health, media errors, wear, temperature).";
        };

        watchedFilesystems = lib.mkOption {
          default = [ ];
          description = "Mountpoints to watch for presence and capacity, with hysteresis thresholds.";
          type = lib.types.listOf (lib.types.submodule {
            options = {
              mount = lib.mkOption {
                type = lib.types.str;
                description = "Mountpoint to check.";
              };
              high = lib.mkOption {
                type = lib.types.ints.between 1 100;
                description = "Percent-used that triggers an alert.";
              };
              low = lib.mkOption {
                type = lib.types.ints.between 1 100;
                description = "Percent-used the host must fall back below to clear the alert.";
              };
            };
          });
        };

        tempHigh = lib.mkOption {
          type = lib.types.ints.positive;
          default = 50;
          description = "Drive temperature in °C that triggers an alert.";
        };

        tempLow = lib.mkOption {
          type = lib.types.ints.positive;
          default = 45;
          description = "Temperature the drive must fall back below to clear the alert.";
        };

        heartbeat = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Weekly all-clear summary. The only thing that distinguishes a
            quiet week from a dead alert path.
          '';
        };
      };

      config = lib.mkMerge [
        {
          # Monitoring consumes the webhook, so monitoring declares it.
          sops.secrets.discord_webhook = { };

          # A ".service" suffix in a roster would make the OnFailure
          # attachment below generate `foo.service.service`.
          assertions = map (u: {
            assertion = !(lib.hasSuffix ".service" u);
            message = "dendriticNixOS.monitoring: '${u}' must be a bare unit name.";
          }) hookedUnits;

          # ──── Generic failed-units watcher: catches what the rosters miss ────
          systemd.services.failed-units-monitor = {
            description = "Alert on any newly failed systemd units";
            after = [ "boot-notify.service" ];
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "failed-units-monitor";
              ExecStart = pkgs.writeShellScript "failed-units-monitor" ''
                ${shellLib}
                STATE_FILE=/var/lib/failed-units-monitor/failed
                ALL_FILE=$(mktemp)
                EXCL_FILE=$(mktemp)
                CURR_FILE=$(mktemp)

                ${pkgs.systemd}/bin/systemctl --failed --no-legend --plain \
                  | ${pkgs.gawk}/bin/awk '{print $1}' | sort > "$ALL_FILE"
                printf '%s\n' ${lib.escapeShellArgs excludedUnits} | sort > "$EXCL_FILE"
                ${pkgs.coreutils}/bin/comm -23 "$ALL_FILE" "$EXCL_FILE" > "$CURR_FILE"
                touch "$STATE_FILE"

                NEW=$(${pkgs.coreutils}/bin/comm -13 "$STATE_FILE" "$CURR_FILE")
                RESOLVED=$(${pkgs.coreutils}/bin/comm -23 "$STATE_FILE" "$CURR_FILE")

                if [ -n "$NEW" ]; then
                  notify "🚨 **Failed unit(s) on $HOST**:
$NEW"
                fi
                if [ -n "$RESOLVED" ]; then
                  notify "✅ **Unit(s) recovered on $HOST**:
$RESOLVED"
                fi

                mv "$CURR_FILE" "$STATE_FILE"
                rm -f "$ALL_FILE" "$EXCL_FILE"
              '';
            };
          };
          systemd.timers.failed-units-monitor = {
            wantedBy = [ "timers.target" ];
            # No Persistent: a 5-minute cadence has nothing to catch up on,
            # and it would only add a burst at every boot.
            timerConfig = { OnCalendar = "*:0/5"; };
          };

          # ──── Boot notification: know immediately that a boot happened ────
          systemd.services.boot-notify = {
            description = "Discord notification on boot";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            # A completed oneshot reads as inactive, and switch-to-configuration
            # starts every inactive wantedBy unit it finds — so RemainAfterExit
            # is what stops a rebuild from re-announcing the last real boot,
            # and the *IfChanged pair stops an edit to this script doing the same.
            restartIfChanged = false;
            stopIfChanged = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "boot-notify" ''
                ${shellLib}
                BOOTED=$(${pkgs.procps}/bin/uptime -s)
                FAILED=$(${pkgs.systemd}/bin/systemctl --failed --no-legend --plain \
                  | ${pkgs.gawk}/bin/awk '{print $1}')
                MSG="🔌 **$HOST booted** at $BOOTED."
                if [ -n "$FAILED" ]; then
                  MSG="$MSG
⚠️ Failed units at boot:
$FAILED"
                fi

                # Pre-reboot state would otherwise read as a mass recovery on
                # the next poll, since nothing has had a chance to fail yet.
                rm -f /var/lib/failed-units-monitor/failed
                rm -f /var/lib/service-monitor/*

                # Network may still be settling right after boot; retry
                for i in 1 2 3 4 5 6; do
                  if notify "$MSG"; then exit 0; fi
                  sleep 10
                done
              '';
            };
          };

          # ──── Instant crash alerts: event-driven OnFailure, no polling delay ────
          systemd.services."notify-failure@" = {
            description = "Discord failure notification for %i";
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "service-monitor";
              ExecStart = pkgs.writeShellScript "notify-failure" ''
                ${shellLib}
                UNIT="$1"
                SERVICE="''${UNIT%.service}"
                STATE_DIR=/var/lib/service-monitor

                # Pre-mark state so the polling monitor doesn't duplicate the alert
                echo "down" > "$STATE_DIR/$SERVICE"

                # A unit with Restart=on-failure in a crash loop would otherwise
                # emit one webhook per restart and trip Discord's rate limit,
                # which --fail turns into a failed unit of our own.
                CD="$STATE_DIR/lastalert-$SERVICE"
                NOW=$(${pkgs.coreutils}/bin/date +%s)
                LAST=$(cat "$CD" 2>/dev/null || echo 0)
                is_num "$LAST" || LAST=0
                [ $(( NOW - LAST )) -lt 600 ] && exit 0
                echo "$NOW" > "$CD"

                notify "🚨 **Service DOWN on $HOST**: $SERVICE failed (instant alert)."
              '' + " %i";
            };
          };

          # ──── Service up/down poller: recovery messages + safety net ────
          # The roster is assembled from watchedServices registrations made
          # by the modules that own each service (seedbox, arr, jellyfin, …).
          systemd.services.service-monitor = {
            description = "Monitor critical services and alert on state transitions";
            after = [ "boot-notify.service" ];
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "service-monitor";
              ExecStart = pkgs.writeShellScript "service-monitor" ''
                ${shellLib}
                STATE_DIR=/var/lib/service-monitor

                check_service() {
                  SERVICE=$1
                  SF="$STATE_DIR/$SERVICE"
                  PREV=$(cat "$SF" 2>/dev/null || echo "up")
                  if ${pkgs.systemd}/bin/systemctl is-active --quiet "$SERVICE"; then
                    CURR="up"; else CURR="down"; fi

                  if [ "$CURR" = "down" ] && [ "$PREV" = "up" ]; then
                    notify "🚨 **Service DOWN on $HOST**: $SERVICE is not running!"
                  elif [ "$CURR" = "up" ] && [ "$PREV" = "down" ]; then
                    DOWN_SINCE=$(${pkgs.coreutils}/bin/stat -c %y "$SF" 2>/dev/null | cut -d. -f1)
                    notify "✅ **Service RECOVERED on $HOST**: $SERVICE is back up (was down since $DOWN_SINCE)."
                  fi
                  echo "$CURR" > "$SF"
                }

                ${lib.concatMapStrings (s: "check_service ${s}\n") watched}
              '';
            };
          };
          systemd.timers.service-monitor = {
            wantedBy = [ "timers.target" ];
            timerConfig = { OnCalendar = "*:0/15"; };
          };
        }

        # ──── Freshness deadman: only on hosts that registered jobs/paths ────
        (lib.mkIf (jobs != [ ] || paths != [ ]) {
          systemd.services.freshness-monitor = {
            description = "Alert on jobs and data trees that stopped happening";
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "freshness-monitor";
              ExecStart = pkgs.writeShellScript "freshness-monitor" ''
                ${shellLib}
                STATE_DIR=/var/lib/freshness-monitor
                NOW=$(${pkgs.coreutils}/bin/date +%s)

                check_job() {
                  UNIT=$1; MAX=$2
                  SF="$STATE_DIR/job_$UNIT"
                  LAST=$(${pkgs.systemd}/bin/systemctl show -p InactiveExitTimestamp \
                    --value "$UNIT.service" 2>/dev/null)

                  if [ -z "$LAST" ]; then
                    transition "$SF" "never" \
                      "🚨 **Never ran on $HOST**: $UNIT has no recorded run —