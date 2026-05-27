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
