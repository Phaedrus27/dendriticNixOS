{ self, ... }: {
  flake.nixosModules.mewSecurity = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.yubikey
      self.nixosModules.fprintd
      self.nixosModules.mewDisko
    ];

    # Suspend on lid close. The lock itself is handled by noctalia's own
    # lockOnSuspend setting (settings.general.lockOnSuspend = true in
    # noctalia.json), which takes a logind sleep inhibitor and locks before
    # the system sleeps — so no separate lock service is needed here.
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
    };
  };
}