{ self, inputs, ... }: {

  flake.nixosModules.charizardHardware = { config, lib, pkgs, modulesPath, ... }: {
  
    imports =
      [ (modulesPath + "/installer/scan/not-detected.nix")
      ];

    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" =
      { device = "/dev/mapper/luks-bb59877a-e6fb-443d-af1e-485147ca43f2";
        fsType = "ext4";
      };

    boot.initrd.luks.devices."luks-bb59877a-e6fb-443d-af1e-485147ca43f2".device = "/dev/disk/by-uuid/bb59877a-e6fb-443d-af1e-485147ca43f2";

    fileSystems."/boot" =
      { device = "/dev/disk/by-uuid/F022-0675";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

    swapDevices = [ ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
