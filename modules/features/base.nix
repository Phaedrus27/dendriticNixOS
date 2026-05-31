{ ... }: {
  flake.nixosModules.base = { ... }: {
    services.fwupd.enable = true;
    zramSwap.enable = true;
  };
}