{ self, inputs, ... }: {
  flake.nixosModules.environment = { pkgs, ... }: {
    imports = [
      self.nixosModules.niri
      self.nixosModules.nautilus
    ];
  };
}