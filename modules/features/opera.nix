{ self, inputs, ... }: {
  flake.nixosModules.opera = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [ opera ];
  };
}