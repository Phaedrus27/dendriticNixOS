{ self, inputs, ... }: {
  flake.nixosModules.mediaServer = { ... }: {
    imports = [
      self.nixosModules.protonvpn
      self.nixosModules.qbittorrent
      self.nixosModules.arr
      self.nixosModules.jellyfin
      self.nixosModules.caddy
    ];
    services.dnsmasq = {
      enable = true;
      settings = {
        server = [ "192.168.1.1" ];
        listen-address = [ "127.0.0.1" "100.85.58.101" ];
        bind-interfaces = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}