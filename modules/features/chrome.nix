{ self, inputs, ... }: {
  flake.nixosModules.chrome = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.google-chrome ];
  };
}