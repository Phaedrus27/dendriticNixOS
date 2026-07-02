# pidgey hardware — Raspberry Pi 5 in Argon NEO 5, root on M.2 NVMe
#
# Board support comes from nixos-raspberrypi (NOT nixos-hardware): vendor
# kernel + firmware arrive prebuilt from its binary cache, and config.txt is
# generated declaratively. Requires pidgey.nix to instantiate the system via
# inputs.nixos-raspberrypi.lib.nixosSystem, which injects the flake reference
# these board modules expect as a module argument.
{ inputs, ... }:
{
  flake.nixosModules.pidgeyHardware = { lib, ... }: {
    imports = with inputs.nixos-raspberrypi.nixosModules; [
      raspberry-pi-5.base           # vendor kernel, firmware, RPi bootloader; nvme already in initrd
      raspberry-pi-5.page-size-16k  # fixes for the 16k-page default kernel
    ];

    # aarch64 host; set here (not in the wrapper) to mirror the other hosts,
    # which pin hostPlatform from their hardware module.
    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

    # ──── Boot ────
    # Generational RPi bootloader ("kernel", multi-generation) rather than the
    # base module's legacy "kernelboot" default — matches what the sd-image
    # ships, so post-install rebuilds agree with what's on disk.
    boot.loader.raspberry-pi.bootloader = "kernel";
    boot.loader.grub.enable = false;

    # Argon NEO 5's M.2 board is a non-HAT+ PCIe device: PCIE_PROBE=1 in the
    # EEPROM lets the *bootloader* find the NVMe; this dtparam brings the PCIe
    # port up for *Linux*. Gen2 signalling (default) — gen3 is out of spec on
    # the Pi 5 and not worth the stability risk for a DNS box.
    hardware.raspberry-pi.config.all.base-dt-params.pciex1 = {
      enable = true;
      value = "on";
    };

    # ──── Filesystems ────
    # These labels are what the sd-image build writes; dd'ing that image onto
    # the NVMe carries them over, so stage-2 rebuilds on the live system see
    # the same layout the image created. by-label survives enclosure/port
    # reshuffles that change by-uuid/by-path on removable media.
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    fileSystems."/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min" ];
    };
  };
}