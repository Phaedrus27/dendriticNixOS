{ self, inputs, ... }: {
  flake.nixosModules.environment = { pkgs, ... }: {
    imports = [
      self.nixosModules.niri
      self.nixosModules.nautilus
    ];

    environment.systemPackages = with pkgs; [
      proton-vpn
      tailscale-systray
    ];

    networking.networkmanager.enable = true;
  };
}