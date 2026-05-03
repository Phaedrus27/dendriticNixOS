{ self, inputs, ... }: {
  flake.nixosModules.environment = { pkgs, ... }: {
    imports = [
      self.nixosModules.niri
      self.nixosModules.nautilus
    ];

    environment.systemPackages = with pkgs; [
      protonvpn-gui
      tailscale-systray
    ];

    networking.networkmanager.enable = true;
  };
}