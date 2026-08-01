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
                      "🚨 **Never ran on $HOST**: $UNIT has no recorded run — check that its timer is enabled."
                    return
                  fi

                  THEN=$(${pkgs.coreutils}/bin/date -d "$LAST" +%s 2>/dev/null)
                  is_num "$THEN" || { notify "⚠️ **Freshness check failed on $HOST**: unparsable timestamp for $UNIT."; return; }
                  AGE=$(( ( NOW - THEN ) / 3600 ))

                  if [ "$AGE" -gt "$MAX" ]; then
                    transition "$SF" "stale" \
                      "🚨 **Stale job on $HOST**: $UNIT last ran ''${AGE}h ago (limit ''${MAX}h)."
                  else
                    transition "$SF" "ok" \
                      "✅ **Job running again on $HOST**: $UNIT ran ''${AGE}h ago."
                  fi
                }

                check_path() {
                  P=$1; MAX=$2
                  SAFE=$(echo "$P" | tr '/' '_')
                  SF="$STATE_DIR/path$SAFE"

                  if [ ! -d "$P" ]; then
                    transition "$SF" "missing" \
                      "🚨 **Path missing on $HOST**: $P does not exist."
                    return
                  fi

                  NEWEST=$(${pkgs.findutils}/bin/find "$P" -type f -printf '%T@\n' 2>/dev/null \
                    | ${pkgs.coreutils}/bin/sort -n | ${pkgs.coreutils}/bin/tail -1 | cut -d. -f1)

                  if [ -z "$NEWEST" ]; then
                    transition "$SF" "empty" \
                      "🚨 **No data on $HOST**: $P is empty — the producer is connected to nothing."
                    return
                  fi
                  is_num "$NEWEST" || return
                  AGE=$(( ( NOW - NEWEST ) / 3600 ))

                  if [ "$AGE" -gt "$MAX" ]; then
                    transition "$SF" "stale" \
                      "🚨 **Stale data on $HOST**: newest file in $P is ''${AGE}h old (limit ''${MAX}h)."
                  else
                    transition "$SF" "ok" \
                      "✅ **Data flowing again on $HOST**: $P updated ''${AGE}h ago."
                  fi
                }

                ${jobCalls}${pathCalls}
              '';
            };
          };
          systemd.timers.freshness-monitor = {
            wantedBy = [ "timers.target" ];
            timerConfig = { OnCalendar = "hourly"; Persistent = true; RandomizedDelaySec = "5m"; };
          };
        })

        # ──── Disk SMART health: only on hosts that registered disks/NVMe ────
        (lib.mkIf (disks != [ ] || nvmes != [ ]) {
          environment.systemPackages = [ pkgs.smartmontools ];

          systemd.services.disk-monitor = {
            description = "Disk health monitor with Discord alerts";
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "disk-monitor";
              ExecStart = pkgs.writeShellScript "disk-monitor" ''
                ${shellLib}
                STATE_DIR=/var/lib/disk-monitor
                TEMP_HIGH=${toString cfg.tempHigh}
                TEMP_LOW=${toString cfg.tempLow}

                # Exit-bit parsing, not grep: a device that has vanished from
                # the bus prints "failed:" in its error message, which a grep
                # for FAILED would report as a dying disk rather than a gone one.
                smart_state() {
                  ${pkgs.smartmontools}/bin/smartctl -H "$1" >/dev/null 2>&1
                  RC=$?
                  if   [ $(( RC & 3 )) -ne 0 ]; then echo "UNREADABLE"
                  elif [ $(( RC & 8 )) -ne 0 ]; then echo "FAILED"
                  else echo "PASSED"; fi
                }

                check_health() {
                  DISK=$1; SAFE=$2; KIND=$3
                  CURR=$(smart_state "$DISK")
                  HF="$STATE_DIR/health$SAFE"
                  PREV=$(cat "$HF" 2>/dev/null || echo "PASSED")
                  [ "$CURR" = "$PREV" ] && { echo "$CURR" > "$HF"; [ "$CURR" = "PASSED" ]; return; }

                  case "$CURR" in
                    FAILED)
                      notify "🚨 **$KIND FAILURE on $HOST**: $DISK has FAILED its SMART health check! Immediate action required." ;;
                    UNREADABLE)
                      notify "🚨 **$KIND UNREADABLE on $HOST**: $DISK cannot be queried — the device may have dropped off the bus." ;;
                    PASSED)
                      notify "✅ **$KIND readable and passing on $HOST**: $DISK. (Stay suspicious — investigate the earlier state: $PREV.)" ;;
                  esac
                  echo "$CURR" > "$HF"
                  [ "$CURR" = "PASSED" ]
                }

                # Raw-value attributes that only ever matter when they grow.
                check_attr_increase() {
                  SAFE=$1; ATTR=$2; LABEL=$3; DISK=$4; ATTRS=$5
                  AF="$STATE_DIR/$ATTR$SAFE"
                  PREV=$(cat "$AF" 2>/dev/null || echo "0")
                  is_num "$PREV" || PREV=0
                  V=$(echo "$ATTRS" | grep "$ATTR" | head -1 | ${pkgs.gawk}/bin/awk '{print $10}')
                  is_num "$V" || return
                  if [ "$V" -gt "$PREV" ]; then
                    notify "⚠️ **Disk Warning on $HOST**: $DISK $LABEL increased: $PREV → $V."
                  fi
                  echo "$V" > "$AF"
                }

                check_temp() {
                  DISK=$1; SAFE=$2; T=$3
                  is_num "$T" || return
                  TF="$STATE_DIR/temp$SAFE"
                  if [ "$T" -ge "$TEMP_HIGH" ]; then
                    transition "$TF" "hot" \
                      "🔥 **Drive temperature on $HOST**: $DISK is at ''${T}°C (limit ''${TEMP_HIGH}°C) — check airflow."
                  elif [ "$T" -lt "$TEMP_LOW" ]; then
                    transition "$TF" "ok" \
                      "✅ **Drive temperature OK on $HOST**: $DISK back down to ''${T}°C."
                  fi
                }

                check_disk() {
                  DISK=$1
                  SAFE=$(echo "$DISK" | tr '/' '_')
                  check_health "$DISK" "$SAFE" "DISK" || return
                  A=$(${pkgs.smartmontools}/bin/smartctl -A "$DISK" 2>&1)

                  check_attr_increase "$SAFE" "Reallocated_Sector"  "reallocated sectors" "$DISK" "$A"
                  check_attr_increase "$SAFE" "Current_Pending_Sector" "pending sectors"   "$DISK" "$A"

                  # SSD endurance: normalized VALUE (field 4) counts DOWN from
                  # 100, the inverse of the NVMe percentage — this is the only
                  # wear signal on the scratch SSD, which absorbs every write.
                  WF="$STATE_DIR/wear$SAFE"
                  W=$(echo "$A" | grep -E "Wear_Leveling_Count|Media_Wearout_Indicator" \
                    | head -1 | ${pkgs.gawk}/bin/awk '{print $4}')
                  if is_num "$W" && [ "$W" -le 10 ]; then
                    transition "$WF" "worn" \
                      "⚠️ **SSD Wear on $HOST**: $DISK endurance indicator down to $W/100. Plan a replacement."
                  fi

                  T=$(echo "$A" | grep -E "Temperature_Celsius|Airflow_Temperature" \
                    | head -1 | ${pkgs.gawk}/bin/awk '{print $10}')
                  check_temp "$DISK" "$SAFE" "$T"
                }

                check_nvme() {
                  DISK=$1
                  SAFE=$(echo "$DISK" | tr '/' '_')
                  check_health "$DISK" "$SAFE" "NVMe" || return
                  A=$(${pkgs.smartmontools}/bin/smartctl -A "$DISK" 2>&1)

                  MF="$STATE_DIR/mediaerr$SAFE"
                  PREV_M=$(cat "$MF" 2>/dev/null || echo "0")
                  is_num "$PREV_M" || PREV_M=0
                  M=$(echo "$A" | grep -i "Media and Data Integrity Errors" \
                    | ${pkgs.gawk}/bin/awk '{print $NF}' | tr -d ',')
                  if is_num "$M"; then
                    if [ "$M" -gt "$PREV_M" ]; then
                      notify "⚠️ **NVMe Warning on $HOST**: $DISK media errors increased: $PREV_M → $M."
                    fi
                    echo "$M" > "$MF"
                  fi

                  WF="$STATE_DIR/wear$SAFE"
                  PCT=$(echo "$A" | grep -i "Percentage Used" \
                    | ${pkgs.gawk}/bin/awk '{print $NF}' | tr -d '%')
                  if is_num "$PCT" && [ "$PCT" -gt 90 ]; then
                    transition "$WF" "worn" \
                      "⚠️ **NVMe Wear on $HOST**: $DISK is at $PCT% of rated write endurance. Plan a replacement."
                  fi

                  T=$(echo "$A" | grep -i "^Temperature:" | ${pkgs.gawk}/bin/awk '{print $2}')
                  check_temp "$DISK" "$SAFE" "$T"
                }

                ${diskCalls}${nvmeCalls}
              '';
            };
          };
          systemd.timers.disk-monitor = {
            wantedBy = [ "timers.target" ];
            # Off midnight so the SMART sweep neither collides with snapraid-sync
            # nor lands its report while nobody is awake to read it.
            timerConfig = { OnCalendar = "09:00"; Persistent = true; RandomizedDelaySec = "15m"; };
          };
        })

        # ──── Filesystem space: only on hosts that registered filesystems ────
        (lib.mkIf (fses != [ ]) {
          systemd.services.disk-space-monitor = {
            description = "Filesystem presence and space monitor with Discord alerts";
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "disk-space-monitor";
              ExecStart = pkgs.writeShellScript "disk-space-monitor" ''
                ${shellLib}
                STATE_DIR=/var/lib/disk-space-monitor

                check_fs() {
                  MOUNT=$1; HIGH=$2; LOW=$3
                  SAFE=$(echo "$MOUNT" | tr '/' '_')
                  SF="$STATE_DIR/space$SAFE"

                  # df falls back to the parent filesystem for an unmounted
                  # path, so a missing disk would report as healthy free space.
                  if ! ${pkgs.util-linux}/bin/findmnt -M "$MOUNT" >/dev/null 2>&1; then
                    transition "$SF" "unmounted" \
                      "🚨 **Mount missing on $HOST**: $MOUNT is not mounted."
                    return
                  fi

                  # --output=pcent avoids the field shift awk '$5' suffers when
                  # df wraps a long source name, as mergerfs branch strings do.
                  USAGE=$(${pkgs.coreutils}/bin/df --output=pcent "$MOUNT" 2>/dev/null \
                    | ${pkgs.gawk}/bin/awk 'NR==2' | tr -dc '0-9')
                  if ! is_num "$USAGE"; then
                    notify "⚠️ **Space check failed on $HOST**: could not read usage for $MOUNT."
                    return
                  fi

                  if [ "$USAGE" -gt "$HIGH" ]; then
                    transition "$SF" "alerted" \
                      "⚠️ **Disk space on $HOST**: $MOUNT is at $USAGE% capacity."
                  elif [ "$USAGE" -lt "$LOW" ]; then
                    transition "$SF" "ok" \
                      "✅ **Disk space OK on $HOST**: $MOUNT is back down to $USAGE%."
                  fi
                }

                ${fsCalls}
              '';
            };
          };
          systemd.timers.disk-space-monitor = {
            wantedBy = [ "timers.target" ];
            timerConfig = { OnCalendar = "hourly"; Persistent = true; };
          };
        })

        # ──── Heartbeat: distinguishes a quiet week from a dead alert path ────
        (lib.mkIf cfg.heartbeat {
          systemd.services.heartbeat = {
            description = "Weekly monitoring all-clear with Discord summary";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "heartbeat" ''
                ${shellLib}
                NOW=$(${pkgs.coreutils}/bin/date +%s)
                REPORT="💚 **Weekly monitor report on $HOST** (up since $(${pkgs.procps}/bin/uptime -s))"

                FAILED=$(${pkgs.systemd}/bin/systemctl --failed --no-legend --plain \
                  | ${pkgs.gawk}/bin/awk '{print $1}' | tr '\n' ' ')
                if [ -n "$FAILED" ]; then
                  REPORT="$REPORT
⚠️ Failed units: $FAILED"
                else
                  REPORT="$REPORT
✅ No failed units"
                fi

                report_fs() {
                  MOUNT=$1
                  if ! ${pkgs.util-linux}/bin/findmnt -M "$MOUNT" >/dev/null 2>&1; then
                    REPORT="$REPORT
🚨 $MOUNT NOT MOUNTED"
                    return
                  fi
                  U=$(${pkgs.coreutils}/bin/df --output=pcent "$MOUNT" 2>/dev/null \
                    | ${pkgs.gawk}/bin/awk 'NR==2' | tr -dc '0-9')
                  REPORT="$REPORT
- $MOUNT $U%"
                }

                report_job() {
                  UNIT=$1
                  LAST=$(${pkgs.systemd}/bin/systemctl show -p InactiveExitTimestamp \
                    --value "$UNIT.service" 2>/dev/null)
                  THEN=$(${pkgs.coreutils}/bin/date -d "$LAST" +%s 2>/dev/null)
                  if is_num "$THEN"; then
                    REPORT="$REPORT
- $UNIT ran $(( ( NOW - THEN ) / 3600 ))h ago"
                  else
                    REPORT="$REPORT
🚨 $UNIT NEVER RAN"
                  fi
                }

                ${lib.concatMapStrings (f: "report_fs ${f.mount}\n") fses}
                ${lib.concatMapStrings (j: "report_job ${j.unit}\n") jobs}

                notify "$REPORT"
              '';
            };
          };
          systemd.timers.heartbeat = {
            wantedBy = [ "timers.target" ];
            timerConfig = { OnCalendar = "Sun 10:00"; Persistent = true; };
          };
        })

        # OnFailure attachments for instant crash alerts, merged as a
        # separate fragment so the wholesale `systemd.services` assignment
        # doesn't collide with the named definitions above.
        {
          systemd.services = lib.genAttrs hookedUnits
            (name: { unitConfig.OnFailure = [ "notify-failure@%n.service" ]; });
        }
      ];
    };
}