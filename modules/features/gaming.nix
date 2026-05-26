{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, config, ... }: {
    programs.steam = {
      enable = true;
      protontricks.enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
    programs.gamescope.enable = true;
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };
    hardware.steam-hardware.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      heroic
      lm_sensors          # temp readouts
      nvtopPackages.amd   # real-time GPU + CPU monitor
      stress-ng           # stability testing
      s-tui               # TUI stress test + live temp/freq view
    ];
  };
}