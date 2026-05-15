{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, ... }: {

    sops.secrets.discord_webhook = {};

    services.smartd = {
      enable = true;
      alertCmd = pkgs.writeShellScript "smartd-discord-alert" ''
        WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
        curl -s -X POST "$WEBHOOK" \
          -H "Content-Type: application/json" \
          -d "{\"content\": \"⚠️ **SMART Alert on squirtle**: $SMARTD_MESSAGE\"}"
      '';
      devices = [
        { device = "/dev/sda"; }
        { device = "/dev/sdb"; }
      ];
    };
  };
}