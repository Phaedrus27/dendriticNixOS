{ self, inputs, ... }: {
  flake.nixosModules.screenshot = { lib, pkgs, config, ... }: let
    # Region capture — select an area, save with timestamp, copy to clipboard
    screenshotRegion = pkgs.writeShellScriptBin "screenshot-region" ''
      set -eu
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      # Abort cleanly (no file) if the user cancels the selection with Escape
      geometry=$(${pkgs.slurp}/bin/slurp) || exit 0
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
      ${pkgs.grim}/bin/grim -g "$geometry" "$file"
      ${pkgs.wl-clipboard}/bin/wl-copy < "$file"
    '';

    # Fullscreen capture — save with timestamp, copy to clipboard
    screenshotFull = pkgs.writeShellScriptBin "screenshot-full" ''
      set -eu
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
      ${pkgs.grim}/bin/grim "$file"
      ${pkgs.wl-clipboard}/bin/wl-copy < "$file"
    '';
  in {
    environment.systemPackages = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      screenshotRegion
      screenshotFull
    ];
  };
}