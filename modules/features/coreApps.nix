{ self, inputs, ... }: {
  flake.nixosModules.coreApps = { pkgs, ... }: {
    # Apps that exist on every workstation, regardless of host or session.
    imports = [
      self.nixosModules.firefox
      self.nixosModules.obsidian
    ];

    environment.systemPackages = with pkgs; [
      vscodium
      vesktop
      vlc
    ];
  };
}