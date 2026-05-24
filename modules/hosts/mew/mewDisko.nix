{ self, inputs, ... }: {
  flake.nixosModules.mewDisko = { lib, ... }: {
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

    # Disable legacy FIDO2 support — systemd initrd handles it instead
    boot.initrd.luks.fido2Support = false;

    # Tell systemd-cryptsetup to try FIDO2 first, fall back to passphrase
    boot.initrd.luks.devices."cryptroot" = {
      device = "/dev/disk/by-partlabel/disk-main-luks";
      crypttabExtraOpts = [ "fido2-device=auto" ];
    };
  };
}