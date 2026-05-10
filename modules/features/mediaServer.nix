{ self, inputs, ... }: {
  flake.nixosModules.mediaServer = { ... }: {
    imports = [
      self.nixosModules.protonvpn
      self.nixosModules.qbittorrent
      self.nixosModules.arr
      self.nixosModules.jellyfin
      self.nixosModules.caddy
    ];
  };
}