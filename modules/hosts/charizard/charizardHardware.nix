{ self, inputs, ... }: {
  flake.nixosModules.charizardHardware = { config, lib, pkgs, modulesPath, ... }: {
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

    # ── Boot & initrd ────────────────────────────────────────────────────────
    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" "atlantic" ];
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

    # ── Networked LUKS unlock (Tang on pidgey) ───────────────────────────────
    # clevis is attempted first; on failure (pidgey/tang down) systemd-cryptsetup
    # falls through to the existing fido2-device=auto / passphrase flow, so the
    # only hard dependency added is on the *unattended* path. Paired with WOL
    # below, a powered-off charizard is remotely bootable to the greeter.
    # Revocation: cryptsetup luksKillSlot <dev> <4> + delete the JWE.

    # Mirror the stage-2 static address: the unlock must not additionally depend
    # on the UDR's DHCP being healthy at boot.
    boot.initrd.systemd.network = {
      enable = true;
      networks."10-lan" = {
        matchConfig.Name = "enp7s0";
        address = [ "192.168.1.6/24" ];
        routes = [ { Gateway = "192.168.1.1"; } ];
      };
    };

    # JWE is ciphertext bound to pidgey's tang keys: safe in git, safe in the
    # initrd on unencrypted /boot. Re-enroll if /var/lib/tang is ever lost.
    boot.initrd.clevis = {
      enable = true;
      useTang = true;
      devices."luks-bb59877a-e6fb-443d-af1e-485147ca43f2".secretFile = ./charizard-root.jwe;
    };

    # WOL: udev re-arms magic-packet wake every boot — the atlantic driver
    # currently defaults to "g", but pin it rather than trust a driver default
    # across kernel bumps. Firmware half lives in BIOS: PCI-E power-on, ErP off.
    # Verify: ethtool enp7s0 | grep Wake-on   → "g"
    networking.interfaces.enp7s0.wakeOnLan.enable = true;

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

    # Build aarch64 closures (pidgey) locally: heavyweight artifacts come from
    # binary caches, but config-specific derivations and image assembly must
    # still *execute* as aarch64 — qemu-user makes that possible on x86_64.
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

    # ── Platform & firmware ──────────────────────────────────────────────────
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  };
}