{ ... }: {
  flake.nixosModules.base = { ... }: {
    services.fwupd.enable = true;
    zramSwap.enable = true;

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    nix.optimise.automatic = true;
    services.journald.extraConfig = "SystemMaxUse=500M";
  };
}