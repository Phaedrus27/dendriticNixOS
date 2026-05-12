{ self, inputs, ... }: {
  flake.nixosModules.chromium = { pkgs, ... }: {
    environment.systemPackages.pkgs = [ 
      chromium
      keychron-udev-rules
    ];
  };
}