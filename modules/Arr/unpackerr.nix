{ self, inputs, ... }: {
  flake.nixosModules.unpackerr = { config, pkgs, ... }: {

    sops.secrets.sonarr_api_key = {};
    sops.secrets.radarr_api_key = {};

    systemd.services.unpackerr = {
      description = "Unpackerr - Extract downloads for Sonarr and Radarr";
      after = [ "network.target" "sonarr.service" "radarr.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "unpackerr";
        Group = "media";
        ExecStart = pkgs.writeShellScript "unpackerr-start" ''
          ${pkgs.unpackerr}/bin/unpackerr \
            --sonarr.url=http://localhost:8989 \
            --sonarr.api_key="$(cat ${config.sops.secrets.sonarr_api_key.path})" \
            --sonarr.paths=/mnt/storage/downloads \
            --radarr.url=http://localhost:7878 \
            --radarr.api_key="$(cat ${config.sops.secrets.radarr_api_key.path})" \
            --radarr.paths=/mnt/storage/downloads
        '';
        Restart = "on-failure";
      };
    };

    users.users.unpackerr = {
      isSystemUser = true;
      group = "media";
    };

  };
}