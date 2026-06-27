# pidgey hardware — Raspberry Pi 5, USB SSD boot
{ inputs, ... }:
{
  flake.nixosModules.pidgeyHardware = { lib, ... }: {
    imports = [ inputs.nixos-hardware.nixosModules.raspberry-pi-5 ];

    # aarch64 host; set here (not in the wrapper) to mirror the other hosts,
    # which pin hostPlatform from their hardware module.
    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

    # ──── Boot ────
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.grub.enable = false;

    # Root lives on the USB SSD. by-label survives enclosure/port reshuffles
    # that change the by-uuid path on USB storage controllers.
    fileSystems."/" = {
      device = "/dev/disk/by-label/pidgey-root";
      fsType = "ext4";
    };
  };
}