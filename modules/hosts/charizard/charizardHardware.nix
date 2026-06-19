{ self, inputs, ... }: {
  flake.nixosModules.charizardHardware = { config, lib, pkgs, modulesPath, ... }: {
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

    # ── Boot & initrd ────────────────────────────────────────────────────────
    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    boot.kernelParams = [
      "amd_pstate=active"                  # EPP-based freq scaling (Zen 5)
      "amdgpu.ppfeaturemask=0xffffffff"    # unlock GPU OC/UV controls
    ];

    # Required for FIDO2 LUKS unlock at boot
    boot.initrd.systemd.enable = true;
    boot.initrd.luks.fido2Support = false;
    boot.initrd.luks.devices."luks-bb59877a-e6fb-443d-af1e-485147ca43f2" = {
      device = "/dev/disk/by-uuid/bb59877a-e6fb-443d-af1e-485147ca43f2";
      crypttabExtraOpts = [ "fido2-device=auto" ];
    };

    # ── Filesystems ──────────────────────────────────────────────────────────
    fileSystems."/" = {
      device = "/dev/mapper/luks-bb59877a-e6fb-443d-af1e-485147ca43f2";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/F022-0675";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    fileSystems."/mnt/data" = {
      device = "/dev/disk/by-uuid/df31339b-c019-422f-a330-51a42c4d54ae";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };

    swapDevices = [ ];

    # ── Platform & firmware ──────────────────────────────────────────────────
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  };
}