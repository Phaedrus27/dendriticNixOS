{ self, inputs, ... }: {
  flake.nixosModules.nautilus = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ 
      nautilus
      gvfs
    ];
    services.gvfs.enable = true;
  };
}