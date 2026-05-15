{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, lib, ... }: {

    environment.systemPackages = [ pkgs.smartmontools ];

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

            # Check for reallocated sectors
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
  };
}