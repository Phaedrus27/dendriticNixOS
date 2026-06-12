{ self, inputs, ... }: {
  flake.nixosModules.unpackerr = { config, pkgs, ... }: {

    sops.secrets.sonarr_api_key = { owner = "unpackerr"; };
    sops.secrets.radarr_api_key = { owner = "unpackerr"; };

    users.users.unpackerr = {
      isSystemUser = true;
      group = "media";
    };

    systemd.services.unpackerr = {
      description = "Unpackerr - Extract downloads for Sonarr and Radarr";
      after = [ "network.target" "sonarr.service" "radarr.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        UN_SONARR_0_URL = "http://localhost:8989";
        UN_SONARR_0_PATHS_0 = "/mnt/storage/downloads";
        UN_SONARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
        UN_RADARR_0_URL = "http://localhost:7878";
        UN_RADARR_0_PATHS_0 = "/mnt/storage/downloads";
        UN_RADARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
      };
      serviceConfig = {
        Type = "simple";
        User = "unpackerr";
        Group = "media";
        Restart = "on-failure";
        ExecStart = pkgs.writeShellScript "unpackerr-start" ''
          export UN_SONARR_0_API_KEY=$(cat ${config.sops.secrets.sonarr_api_key.path})
          export UN_RADARR_0_API_KEY=$(cat ${config.sops.secrets.radarr_api_key.path})
          exec ${pkgs.unpackerr}/bin/unpackerr
        '';
      };
    };

  };
}