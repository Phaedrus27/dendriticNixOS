{ self, inputs, ... }: {
  flake.nixosModules.environment = { pkgs, ... }: {
    imports = [
      self.nixosModules.nautilus
      self.nixosModules.niri
    ];

    environment.systemPackages = with pkgs; [
      proton-vpn
      tailscale-systray
    ];

    networking.networkmanager.enable = true;
  };
}