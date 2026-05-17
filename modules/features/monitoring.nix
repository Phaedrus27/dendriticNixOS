{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.smartmontools ];

    # Disk health monitor
    systemd.services.disk-monitor = {
      description = "Disk health monitor with Discord alerts";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "disk-monitor" ''
          WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
          check_disk() {
            DISK=$1
            RESULT=$(${pkgs.smartmontools}/bin/smartctl -H $DISK 2>&1)
            STATUS=$(echo "$RESULT" | grep -i "overall-health\|PASSED\|FAILED")
            if echo "$STATUS" | grep -qi "FAILED"; then
              ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "{\"content\": \"🚨 **DISK FAILURE on squirtle**: $DISK has FAILED its SMART health check! Immediate action required.\"}"
            fi
            REALLOCATED=$(${pkgs.smartmontools}/bin/smartctl -A $DISK 2>&1 | grep "Reallocated_Sector" | awk '{print $10}')
            if [ ! -z "$REALLOCATED" ] && [ "$REALLOCATED" -gt "0" ]; then
              ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "{\"content\": \"⚠️ **Disk Warning on squirtle**: $DISK has $REALLOCATED reallocated sectors.\"}"
            fi
          }
          check_disk /dev/sda
          check_disk /dev/sdb
        '';
      };
    };
    systemd.timers.disk-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Cache space monitor
    systemd.services.cache-space-monitor = {
      description = "Cache space monitor with Discord alerts";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "cache-space-monitor" ''
          WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
          USAGE=$(${pkgs.coreutils}/bin/df /mnt/cache | ${pkgs.gawk}/bin/awk 'NR==2 {print $5}' | tr -d '%')
          if [ "$USAGE" -gt "90" ]; then
            ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
              -H "Content-Type: application/json" \
              -d "{\"content\": \"⚠️ **Cache Warning on squirtle**: /mnt/cache is at $USAGE% capacity.\"}"
          fi
        '';
      };
    };
    systemd.timers.cache-space-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    # Cache mover failure alert
    systemd.services.cache-mover-monitor = {
      description = "Alert on cache-mover failure";
      after = [ "cache-mover.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "cache-mover-monitor" ''
          WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
          if ! ${pkgs.systemd}/bin/systemctl is-active --quiet cache-mover.service; then
            STATUS=$(${pkgs.systemd}/bin/systemctl status cache-mover.service | ${pkgs.coreutils}/bin/tail -5)
            ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
              -H "Content-Type: application/json" \
              -d "{\"content\": \"🚨 **Cache Mover FAILED on squirtle**: The nightly cache mover did not complete successfully.\"}"
          fi
        '';
      };
    };
    systemd.timers.cache-mover-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # SnapRAID sync failure alert
    systemd.services.snapraid-monitor = {
      description = "Alert on snapraid-sync failure";
      after = [ "snapraid-sync.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "snapraid-monitor" ''
          WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
          if ! ${pkgs.systemd}/bin/systemctl is-active --quiet snapraid-sync.service; then
            ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
              -H "Content-Type: application/json" \
              -d "{\"content\": \"🚨 **SnapRAID Sync FAILED on squirtle**: The daily SnapRAID sync did not complete successfully.\"}"
          fi
        '';
      };
    };
    systemd.timers.snapraid-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Service crash alerts
    systemd.services.service-monitor = {
      description = "Monitor critical services and alert on failure";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "service-monitor" ''
          WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
          check_service() {
            SERVICE=$1
            if ! ${pkgs.systemd}/bin/systemctl is-active --quiet "$SERVICE"; then
              ${pkgs.curl}/bin/curl -s -X POST "$WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "{\"content\": \"🚨 **Service DOWN on squirtle**: $SERVICE is not running!\"}"
            fi
          }
          check_service jellyfin
          check_service sonarr
          check_service radarr
          check_service prowlarr
          check_service qbittorrent
          check_service wg-vpn
        '';
      };
    };
    systemd.timers.service-monitor = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };

  };
}