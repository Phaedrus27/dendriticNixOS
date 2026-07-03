{ self, inputs, ... }: {
  flake.nixosModules.mediaServer = { ... }: {
    imports = [
      self.nixosModules.arr
      self.nixosModules.jellyfin
      self.nixosModules.caddy
      self.nixosModules.seedbox
    ];

    dendriticNixOS.monitoring.watchedServices = [ ];
  };
}