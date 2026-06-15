{ self, inputs, ... }: {
  flake.nixosModules.screenshot = { lib, pkgs, config, ... }: let
    # Helper script for region capture — select area, copy to clipboard and save
    screenshotRegion = pkgs.writeShellScriptBin "screenshot-region" ''
      mkdir -p ~/Pictures/Screenshots
      ${pkgs.wayshot}/bin/wayshot \
        --slurp "$(${pkgs.slurp}/bin/slurp)" \
        --stdout \
        | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png \
        | ${pkgs.wl-clipboard}/bin/wl-copy
    '';

    # Helper script for fullscreen capture — copy to clipboard and save
    screenshotFull = pkgs.writeShellScriptBin "screenshot-full" ''
      mkdir -p ~/Pictures/Screenshots
      ${pkgs.wayshot}/bin/wayshot \
        --stdout \
        | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png \
        | ${pkgs.wl-clipboard}/bin/wl-copy
    '';

    vrrToggle = pkgs.writeShellScriptBin "vrr-toggle" ''
      out="DP-1"
      if niri msg outputs \
        | awk -v o="($out)" 'index($0,o){f=1} f && /Variable refresh rate:/{print; exit}' \
        | grep -q 'enabled'; then
        niri msg output "$out" vrr off
        ${pkgs.libnotify}/bin/notify-send -t 1500 "VRR" "Off — $out"
      else
        niri msg output "$out" vrr on
        ${pkgs.libnotify}/bin/notify-send -t 1500 "VRR" "On — $out"
      fi
    '';
  in {
    environment.systemPackages = [
      pkgs.wayshot
      pkgs.slurp
      pkgs.wl-clipboard
      screenshotRegion
      screenshotFull
    ];
  };
}
