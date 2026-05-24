{ self, inputs, ... }: {
  flake.nixosModules.mewDisko = { ... }: {
    imports = [ inputs.disko.nixosModules.disko ];

    disko.devices = {
      disk.main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                # YubiKey FIDO2 enrollment happens post-install:
                # systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2
                settings.allowDiscards = true;
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };

    # Required for FIDO2 unlock at boot
    boot.initrd.systemd.enable = true;
  };
}