{ self, inputs, ... }: {
  flake.nixosModules.mewConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.mewHardware
      self.nixosModules.mewNiri
      self.nixosModules.mewSecurity
      self.nixosModules.syncthing
      self.nixosModules.workstation     
      self.nixosModules.niriSession
      self.nixosModules.tailscale
      self.nixosModules.base
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "mew";

    # ── Host-specific hardware ──────────────────────────────────────────
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;

    # Deliberately off: tuned conflicted with TLP on this machine
    # Power management handled by the Framework defaults.
    # services.tuned.enable = true;

    services.openssh.enable = true;

    system.stateVersion = "25.11";
  };
}