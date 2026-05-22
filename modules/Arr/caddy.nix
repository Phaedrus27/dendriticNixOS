{ self, inputs, ... }: {
  flake.nixosModules.caddy = { config, lib, pkgs, ... }: {
    services.caddy = {
      enable = true;
      virtualHosts = {
        "http://radarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:7878
          '';
        };
        "http://sonarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:8989
          '';
        };
        "http://prowlarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:9696
          '';
        };
        "http://bazarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:6767
          '';
        };
        "http://jellyfin.home" = {
          extraConfig = ''
            reverse_proxy localhost:8096
          '';
        };
        "http://qbittorrent.home" = {
          extraConfig = ''
            reverse_proxy 10.99.0.2:8080
          '';
        };
        "http://squirtle.home" = {
          extraConfig = ''
            respond "squirtle is alive"
          '';
        };
        "http://paperless.home" = {
          extraConfig = ''
            reverse_proxy localhost:28981
          '';
          "http://seerr.home".extraConfig = ''
        reverse_proxy localhost:5055
      '';
        };
      };
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}