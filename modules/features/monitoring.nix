{ self, inputs, ... }: {
  flake.nixosModules.monitoring = { config, pkgs, ... }: {

    services.smartd = {
      enable = true;
      autodetect = true;
      defaults = "-a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,45,55 -m root -M exec ${pkgs.writeShellScript "smartd-discord-alert" ''
        WEBHOOK=$(cat ${config.sops.secrets.discord_webhook.path})
        curl -s -X POST "$WEBHOOK" \
          -H "Content-Type: application/json" \
          -d "{\"content\": \"⚠️ **SMART Alert on squirtle**: $SMARTD_MESSAGE\"}"
      ''}";
    };
  };
}