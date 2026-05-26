{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, config, ... }: {

    # ── Steam & Proton ───────────────────────────────────────────────────────
    programs.steam = {
      enable = true;
      protontricks.enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # ── Gamescope & Gamemode ─────────────────────────────────────────────────
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

    # ── GPU tuning ───────────────────────────────────────────────────────────
    programs.corectrl = {
      enable = true;
      gpuOverclock.enable = true;
    };
    users.users.phaedrus.extraGroups = [ "corectrl" ];

    # ── Game streaming (Sunshine host) ───────────────────────────────────────
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;    # required for KMS capture on Wayland/Niri
      openFirewall = true;
    };

    # ── Hardware ─────────────────────────────────────────────────────────────
    hardware.steam-hardware.enable = true;
    services.udev.packages = [ pkgs.game-devices-udev-rules ];

    # ── Packages ─────────────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      # Launchers
      heroic             # GOG & Epic
      lutris             # Battle.net, EA, legacy titles
      bottles            # Windows app/game compatibility

      # MangoHud & overlay
      mangohud
      goverlay           # MangoHud GUI config

      # Vulkan
      vkbasalt           # post-processing layer (sharpening, AA)

      # Monitoring & profiling
      lm_sensors
      nvtopPackages.amd
      stress-ng
      s-tui
    ];
  };
}