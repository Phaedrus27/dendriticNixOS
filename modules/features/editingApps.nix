{ self, inputs, ... }: {
  flake.nixosModules.editingApps = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      gimp
      audacity
    ];
  };
}