{ self, inputs, ... }: {
  flake.nixosModules.chromium = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ 
      chromium
    ];
  };
}