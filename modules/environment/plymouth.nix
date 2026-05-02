{ self, inputs, ... }: {
  flake.nixosModules.plymouth = { lib, config, pkgs, ... }: {
    boot.initrd.systemd.enable = true;
    boot.plymouth = {
      enable = true;
      theme = "spinner";
    };
    boot.initrd.systemd.extraBin = {
      plymouthd = "${pkgs.plymouth}/bin/plymouthd";
      plymouth = "${pkgs.plymouth}/bin/plymouth";
    };
    boot.consoleLogLevel = 0;
    boot.kernelParams = [ "quiet" "splash" "udev.log_level=0" ];
    boot.initrd.verbose = false;
  };
}