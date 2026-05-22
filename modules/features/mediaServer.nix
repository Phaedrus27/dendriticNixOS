{ self, inputs, ... }: {
  flake.nixosModules.mediaServer = { ... }: {
    imports = [
      self.nixosModules.protonvpn
      self.nixosModules.qbittorrent
      self.nixosModules.arr
      self.nixosModules.jellyfin
      self.nixosModules.caddy
      self.nixosModules.monitoring
      self.nixosModules.unpackerr
      self.nixosModules.seerr
    ];

    services.dnsmasq = {
      enable = true;
      settings = {
        server = [ "192.168.1.1" ];
        listen-address = [ "127.0.0.1" "100.85.58.101" ];
        bind-interfaces = true;
        address = [
          "/radarr.home/100.85.58.101"
          "/sonarr.home/100.85.58.101"
          "/prowlarr.home/100.85.58.101"
          "/bazarr.home/100.85.58.101"
          "/jellyfin.home/100.85.58.101"
          "/qbittorrent.home/100.85.58.101"
          "/squirtle.home/100.85.58.101"
          "/paperless.home/100.85.58.101"
          "/seerr.home/100.85.58.101"
        ];
      };
    };

    systemd.services.dnsmasq = {
      after = [ "tailscaled.service" "network-online.target" ];
      wants = [ "tailscaled.service" "network-online.target" ];
    };
  };
}