{ self, inputs, ... }: {
  flake.nixosModules.niriSession = { pkgs, ... }: {
    imports = [
      self.nixosModules.niri
      self.nixosModules.screenshot       # grim/wayland tooling: session-specific
      self.nixosModules.nautilus         # "the file manager for this session";
                                         # GNOME would bring its own
    ];

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "niri-session";
        user = "phaedrus";
      };
    };
  };
}