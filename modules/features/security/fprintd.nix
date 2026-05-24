{ self, ... }: {
  flake.nixosModules.fprintd = { ... }: {
    services.fprintd.enable = true;
    security.pam.services.login.fprintAuth = true;
    security.pam.services.sudo.fprintAuth = true;
    security.pam.services.swaylock.fprintAuth = true;
  };
}