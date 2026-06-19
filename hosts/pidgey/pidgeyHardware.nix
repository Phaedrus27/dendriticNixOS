# pidgey hardware — Raspberry Pi 5, USB SSD boot
{ inputs, ... }:
{
  flake.modules.nixos.pidgey-hardware = {
    imports = [ inputs.nixos-hardware.nixosModules.raspberry-pi-5 ];

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