{ self, inputs, ... }: {
  flake.nixosModules.jellyfinApp = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.jellyfin-media-player ];
  };
}