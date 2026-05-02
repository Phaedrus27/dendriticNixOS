{ self, inputs, ... }: {
  flake.nixosModules.nautilus = { pkgs, ... }: {
    programs.nautilus-portal.enable = true;
    environment.systemPackages = [ pkgs.nautilus ];
  };
}