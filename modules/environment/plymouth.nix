{ self, inputs, ... }: {
  flake.nixosModules.plymouth = { lib, config, ... }: {
    options.modules.plymouth = {
      enable = lib.mkEnableOption "plymouth boot splash";
    };

    config = lib.mkIf config.modules.plymouth.enable {
      boot.plymouth.enable = true;
      boot.consoleLogLevel = 0;
      boot.kernelParams = [ "quiet" "splash" "udev.log_level=0" ];
    };
  };
}