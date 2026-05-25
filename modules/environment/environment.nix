{ self, inputs, ... }: {
  flake.nixosModules.environment = { pkgs, ... }: {
    imports = [
      self.nixosModules.nautilus
      self.nixosModules.niri
      self.nixosModules.firefox
    ];

    environment.systemPackages = with pkgs; [
      proton-vpn
      tailscale-systray
    ];

    networking.networkmanager.enable = true;

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd niri-session";
          user = "greeter";
        };
      };
    };
  };
}