{ self, inputs, ... }: {
  flake.nixosModules.nautilus = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ nautilus ];
    services.gvfs.enable = true;
  };
}