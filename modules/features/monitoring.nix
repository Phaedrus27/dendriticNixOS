{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, ... }: {

    services.smartd = {
      enable = true;
      autodetect = true;
      extraOptions = [
        "-M exec ${pkgs.writeShellScript "smartd-discord-alert" ''
          WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
          curl -s -X POST "$WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"⚠️ **SMART Alert on squirtle**: $SMARTD_MESSAGE\"}"
        ''}"
      ];
    };
  };
}