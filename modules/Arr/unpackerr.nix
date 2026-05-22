{ self, inputs, ... }: {
  flake.nixosModules.unpackerr = { config, pkgs, ... }: {

    sops.secrets.sonarr_api_key = {};
    sops.secrets.radarr_api_key = {};

    services.unpackerr = {
      enable = true;
      settings = {
        sonarr = [{
          url = "http://localhost:8989";
          api_key = "filepath:${config.sops.secrets.sonarr_api_key.path}";
          paths = [ "/mnt/storage/downloads" ];
          protocols = "torrent,TorrentDownloadProtocol";
        }];
        radarr = [{
          url = "http://localhost:7878";
          api_key = "filepath:${config.sops.secrets.radarr_api_key.path}";
          paths = [ "/mnt/storage/downloads" ];
          protocols = "torrent,TorrentDownloadProtocol";
        }];
      };
    };
  };
}