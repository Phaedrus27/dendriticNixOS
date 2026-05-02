{ self, inputs, ... }: {
  flake.nixosModules.plymouth = { lib, ... }: {
    boot.plymouth.enable = true;
    boot.consoleLogLevel = 0;
    boot.kernelParams = [ "quiet" "splash" "udev.log_level=0" ];
  };
}