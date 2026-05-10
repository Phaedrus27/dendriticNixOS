{ self, inputs, ... }: {
  flake.nixosModules.caddy = { config, lib, pkgs, ... }: {

    services.caddy = {
      enable = true;
      virtualHosts = {
        "radarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:7878
          '';
        };
        "sonarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:8989
          '';
        };
        "prowlarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:9696
          '';
        };
        "bazarr.home" = {
          extraConfig = ''
            reverse_proxy localhost:6767
          '';
        };
        "jellyfin.home" = {
          extraConfig = ''
            reverse_proxy localhost:8096
          '';
        };
        "qbittorrent.home" = {
          extraConfig = ''
            reverse_proxy 10.99.0.2:8080
          '';
        };
        "squirtle.home" = {
          extraConfig = ''
            respond "squirtle is alive"
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}