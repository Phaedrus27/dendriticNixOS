# ════════════════════════════════════════════════════════════════════════
# coreApps — fleet-wide workstation app manifest
#
#   imports          firefox module
#   packages         editors, comms, media, notes
#   xdg defaults     image/* handler pinning
#   swayimg config   system-level INI via /etc/xdg
# ════════════════════════════════════════════════════════════════════════
{ self, ... }:
{
  flake.nixosModules.coreApps =
    { lib, pkgs, ... }:
    {
      imports = [ self.nixosModules.firefox ];

      # ──── Packages ────
      environment.systemPackages = with pkgs; [
        vscodium
        vesktop
        vlc
        obsidian
        spotify
        swayimg
      ];

      # ──── XDG default applications ────
      # Nothing here claims image/* except chromium, gimp and vlc, so an unset
      # default resolves alphabetically to chromium and JPEG was pinned to gimp
      # in a stray ~/.config/mimeapps.list. Pin the viewer explicitly instead.
      xdg.mime.defaultApplications =
        lib.genAttrs [
          "image/png"
          "image/jpeg"
          "image/gif"
          "image/webp"
          "image/tiff"
          "image/bmp"
          "image/avif"
        ] (_: "swayimg.desktop");

      # ──── swayimg ────
      # Config lands in /etc/xdg rather than ~/.config: swayimg searches
      # XDG_CONFIG_DIRS and never writes back, so the fleet owns the file
      # without home-manager and without the app clobbering it on exit.
      environment.etc."xdg/swayimg/config".text = ''
        [general]
        mode = viewer
        position = parent

        [viewer]
        window = #1e1e2e
        antialiasing = yes
        scale = fit
      '';

      # ──── mimeapps.list ────
      # ~/.config/mimeapps.list outranks /etc/xdg/mimeapps.list, so any "open with →
      # always" click silently overrides the flake. Point it at the generated system
      # file so the user copy can't diverge from it.
      systemd.user.tmpfiles.users.phaedrus.rules = [
        "L+ %h/.config/mimeapps.list - - - - /etc/xdg/mimeapps.list"
      ];
    };
}