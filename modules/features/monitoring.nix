{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, lib, ... }:
    let
      # JSON-safe Discord notify, shared by all scripts via sourcing
      notifyLib = ''
        WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
        notify() {
          ${pkgs.jq}/bin/jq -n --arg c "$1" '{content: $c}' \
            | ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
                -H "Content-Type: application/json" -d @-
        }
      '';
    in
    lib.mkMerge [
      {
        environment.systemPackages = [ pkgs.smartmontools ];

        # ── Disk health: SATA disks + NVMe, transition/increase-based ──
        systemd.services.disk-monitor = {
          description = "Disk health monitor with Discord alerts";
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "disk-monitor";
            ExecStart = pkgs.writeShellScript "disk-monitor" ''
              ${notifyLib}
              STATE_DIR=/var/lib/disk-monitor

              check_disk() {
                DISK=$1
                SAFE=$(echo "$DISK" | tr '/' '_')

                # SMART overall health: transitions
                HF="$STATE_DIR/health$SAFE"
                PREV=$(cat "$HF" 2>/dev/null || echo "PASSED")
                if ${pkgs.smartmontools}/bin/smartctl -H "$DISK" 2>&1 | grep -qi "FAILED"; then
                  CURR="FAILED"; else CURR="PASSED"; fi
                if [ "$CURR" = "FAILED" ] && [ "$PREV" = "PASSED" ]; then
                  notify "🚨 **DISK FAILURE on squirtle**: $DISK has FAILED its SMART health check! Immediate action required."
                elif [ "$CURR" = "PASSED" ] && [ "$PREV" = "FAILED" ]; then
                  notify "✅ **Disk recovered on squirtle**: $DISK passes SMART again. (Stay suspicious — investigate the earlier failure.)"
                fi
                echo "$CURR" > "$HF"

                # Reallocated sectors: alert only on increase
                RF="$STATE_DIR/realloc$SAFE"
                PREV_R=$(cat "$RF" 2>/dev/null || echo "0")
                R=$(${pkgs.smartmontools}/bin/smartctl -A "$DISK" 2>&1 \
                  | grep "Reallocated_Sector" | ${pkgs.gawk}/bin/awk '{print $10}')
                R=''${R:-0}
                if [ "$R" -gt "$PREV_R" ]; then
                  notify "⚠️ **Disk Warning on squirtle**: $DISK reallocated sectors increased: $PREV_R → $R."
                fi
                echo "$R" > "$RF"
              }

              check_nvme() {
                DISK=$1
                SAFE=$(echo "$DISK" | tr '/' '_')
                A=$(${pkgs.smartmontools}/bin/smartctl -A "$DISK" 2>&1)

                # Overall health: transitions
                HF="$STATE_DIR/health$SAFE"
                PREV=$(cat "$HF" 2>/dev/null || echo "PASSED")
                if ${pkgs.smartmontools}/bin/smartctl -H "$DISK" 2>&1 | grep -qiE "FAILED"; then
                  CURR="FAILED"; else CURR="PASSED"; fi
                if [ "$CURR" = "FAILED" ] && [ "$PREV" = "PASSED" ]; then
                  notify "🚨 **NVMe FAILURE on squirtle**: $DISK failed its SMART health check!"
                elif [ "$CURR" = "PASSED" ] && [ "$PREV" = "FAILED" ]; then
                  notify "✅ **NVMe recovered on squirtle**: $DISK passes SMART again."
                fi
                echo "$CURR" > "$HF"

                # Media errors: alert only on increase
                MF="$STATE_DIR/mediaerr$SAFE"
                PREV_M=$(cat "$MF" 2>/dev/null || echo "0")
                M=$(echo "$A" | grep -i "Media and Data Integrity Errors" | ${pkgs.gawk}/bin/awk '{print $NF}')
                M=''${M:-0}
                if [ "$M" -gt "$PREV_M" ]; then
                  notify "⚠️ **NVMe Warning on squirtle**: $DISK media errors increased: $PREV_M → $M."
                fi
                echo "$M" > "$MF"

                # Wear level: one-time alert crossing 90% used
                WF="$STATE_DIR/wear$SAFE"
                PREV_W=$(cat "$WF" 2>/dev/null || echo "ok")
                PCT=$(echo "$A" | grep -i "Percentage Used" | ${pkgs.gawk}/bin/awk '{print $NF}' | tr -d '%')
                PCT=''${PCT:-0}
                if [ "$PCT" -gt "90" ] && [ "$PREV_W" = "ok" ]; then
                  notify "⚠️ **NVMe Wear on squirtle**: $DISK is at $PCT% of rated write endurance. Plan a replacement."
                  echo "alerted" > "$WF"
                fi
              }

              check_disk /dev/sda
              check_disk /dev/sdb
              check_nvme /dev/nvme0n1
            '';
          };
        };
        systemd.timers.disk-monitor = {
          wantedBy = [ "timers.target" ];
          timerConfig = { OnCalendar = "daily"; Persistent = true; };
        };

        # ── Filesystem space: cache + root, hysteresis transitions ──
        systemd.services.disk-space-monitor = {
          description = "Filesystem space monitor with Discord alerts";
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "disk-space-monitor";
            ExecStart = pkgs.writeShellScript "disk-space-monitor" ''
              ${notifyLib}
              STATE_DIR=/var/lib/disk-space-monitor

              check_fs() {
                MOUNT=$1; HIGH=$2; LOW=$3
                SAFE=$(echo "$MOUNT" | tr '/' '_')
                SF="$STATE_DIR/space$SAFE"
                USAGE=$(${pkgs.coreutils}/bin/df "$MOUNT" | ${pkgs.gawk}/bin/awk 'NR==2 {print $5}' | tr -d '%')
                PREV=$(cat "$SF" 2>/dev/null || echo "ok")

                if [ "$USAGE" -gt "$HIGH" ] && [ "$PREV" = "ok" ]; then
                  notify "⚠️ **Disk space on squirtle**: $MOUNT is at $USAGE% capacity."
                  echo "alerted" > "$SF"
                elif [ "$USAGE" -lt "$LOW" ] && [ "$PREV" = "alerted" ]; then
                  notify "✅ **Disk space OK on squirtle**: $MOUNT is back down to $USAGE%."
                  echo "ok" > "$SF"
                fi
              }

              check_fs /          85 75
              check_fs /mnt/cache 90 85
            '';
          };
        };
        systemd.timers.disk-space-monitor = {
          wantedBy = [ "timers.target" ];
          timerConfig = { OnCalendar = "hourly"; Persistent = true; };
        };

        # ── Generic failed-units watcher: catches what the service list misses ──
        systemd.services.failed-units-monitor = {
          description = "Alert on any newly failed systemd units";
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "failed-units-monitor";
            ExecStart = pkgs.writeShellScript "failed-units-monitor" ''
              ${notifyLib}
              STATE_FILE=/var/lib/failed-units-monitor/failed
              CURR_FILE=$(mktemp)
              ${pkgs.systemd}/bin/systemctl --failed --no-legend --plain \
                | ${pkgs.gawk}/bin/awk '{print $1}' | sort > "$CURR_FILE"
              touch "$STATE_FILE"

              NEW=$(${pkgs.coreutils}/bin/comm -13 "$STATE_FILE" "$CURR_FILE")
              RESOLVED=$(${pkgs.coreutils}/bin/comm -23 "$STATE_FILE" "$CURR_FILE")

              if [ -n "$NEW" ]; then
                notify "🚨 **Failed unit(s) on squirtle**:
$NEW"
              fi
              if [ -n "$RESOLVED" ]; then
                notify "✅ **Unit(s) recovered on squirtle**:
$RESOLVED"
              fi

              mv "$CURR_FILE" "$STATE_FILE"
            '';
          };
        };
        systemd.timers.failed-units-monitor = {
          wantedBy = [ "timers.target" ];
          timerConfig = { OnCalendar = "*:0/5"; Persistent = true; };
        };

        # ── Boot notification: know immediately that a boot happened ──
        systemd.services.boot-notify = {
          description = "Discord notification on boot";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "boot-notify" ''
              ${notifyLib}
              BOOTED=$(${pkgs.procps}/bin/uptime -s)
              FAILED=$(${pkgs.systemd}/bin/systemctl --failed --no-legend --plain \
                | ${pkgs.gawk}/bin/awk '{print $1}')
              MSG="🔌 **squirtle booted** at $BOOTED."
              if [ -n "$FAILED" ]; then
                MSG="$MSG
⚠️ Failed units at boot:
$FAILED"
              fi
              # Network may still be settling right after boot; retry
              for i in 1 2 3 4 5 6; do
                if notify "$MSG"; then exit 0; fi
                sleep 10
              done
            '';
          };
        };

        # ── Instant crash alerts: event-driven OnFailure, no polling delay ──
        systemd.services."notify-failure@" = {
          description = "Discord failure notification for %i";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "notify-failure" ''
              ${notifyLib}
              UNIT="$1"
              SERVICE="''${UNIT%.service}"
              notify "🚨 **Service DOWN on squirtle**: $SERVICE failed (instant alert)."
              # Pre-mark state so the polling monitor doesn't duplicate the alert
              mkdir -p /var/lib/service-monitor
              echo "down" > "/var/lib/service-monitor/$SERVICE"
            '' + " %i";
          };
        };

        # ── Service up/down poller: recovery messages + safety net ──
        systemd.services.service-monitor = {
          description = "Monitor critical services and alert on state transitions";
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "service-monitor";
            ExecStart = pkgs.writeShellScript "service-monitor" ''
              ${notifyLib}
              STATE_DIR=/var/lib/service-monitor

              check_service() {
                SERVICE=$1
                SF="$STATE_DIR/$SERVICE"
                PREV=$(cat "$SF" 2>/dev/null || echo "up")
                if ${pkgs.systemd}/bin/systemctl is-active --quiet "$SERVICE"; then
                  CURR="up"; else CURR="down"; fi

                if [ "$CURR" = "down" ] && [ "$PREV" = "up" ]; then
                  notify "🚨 **Service DOWN on squirtle**: $SERVICE is not running!"
                elif [ "$CURR" = "up" ] && [ "$PREV" = "down" ]; then
                  DOWN_SINCE=$(${pkgs.coreutils}/bin/stat -c %y "$SF" 2>/dev/null | cut -d. -f1)
                  notify "✅ **Service RECOVERED on squirtle**: $SERVICE is back up (was down since $DOWN_SINCE)."
                fi
                echo "$CURR" > "$SF"
              }

              check_service jellyfin
              check_service sonarr
              check_service radarr
              check_service prowlarr
              check_service qbittorrent
              check_service wg-vpn
              check_service dnsmasq
            '';
          };
        };
        systemd.timers.service-monitor = {
          wantedBy = [ "timers.target" ];
          timerConfig = { OnCalendar = "*:0/15"; Persistent = true; };
        };

        # ── SnapRAID sync failure alert — enable when disk #3 arrives ──
        # When you do: don't use `is-active` (oneshots are always inactive).
        # Just attach the template:
        #   systemd.services.snapraid-sync.unitConfig.OnFailure =
        #     [ "notify-failure@%n.service" ];
      }

      # OnFailure attachments for instant crash alerts, merged as a
      # separate fragment so the wholesale `systemd.services` assignment
      # doesn't collide with the named definitions above.
      {
        systemd.services = lib.genAttrs
          [ "jellyfin" "sonarr" "radarr" "prowlarr" "qbittorrent" "wg-vpn" "dnsmasq" ]
          (name: { unitConfig.OnFailure = [ "notify-failure@%n.service" ]; });
      }
    ];
}