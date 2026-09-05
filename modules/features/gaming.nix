{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, config, ... }:
  let
    # MangoHud + vkBasalt configs live in the Nix store and are selected via the
    # env vars further down.
    mangoHudConf = pkgs.writeText "MangoHud.conf" ''
      # MANGOHUD=1 (sessionVariables) loads the layer into every Vulkan app;
      # no_display keeps it hidden until toggled. Keybinds are read by MangoHud
      # itself, not the compositor: keysyms are XKB names, so Shift_R matches
      # right Shift only.
      no_display=1
      toggle_hud=Shift_R+F11
      # Displace toggle_hud_position: its default is Shift_R+F11, which would
      # fire both actions on the toggle combo.
      toggle_hud_position=Shift_L+F11
      # Telemetry shown when visible
      fps
      frametime=1
      frame_timing=1
      gpu_stats
      gpu_temp
      cpu_stats
      cpu_temp
      ram
      vram
      # Cosmetic
      font_size=20
      position=top-left
      background_alpha=0.4
    '';

  in {

    # ──── Steam & Proton ────
    programs.steam = {
      enable = true;
      protontricks.enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # ──── Gamescope & Gamemode ────
    programs.gamescope.enable = true;
    programs.gamemode = {
      enable = true;
      settings.general.renice = 10;
      # No gpu block: a gamemode performance level and a LACT profile both write
      # power_dpm_force_performance_level, and whichever applied last silently
      # wins. GPU clocks are LACT's alone.
    };

    # ──── GPU tuning ────
    # LACT over corectrl: corectrl only enforces its saved profile while the GUI
    # runs, which is why it needed a spawn-at-startup entry. lactd applies at
    # boot, independent of the session — so a Sunshine wake or a gamescope
    # session gets the same clocks as a seated niri login.
    #
    # ppfeaturemask stated explicitly, not left to the option default:
    # 0xfffd7fff is the conservative mask (upstream associates the two extra
    # bits in 0xffffffff with flicker) and DP-1 is flicker-sensitive.
    services.lact.enable = true;
    hardware.amdgpu.overdrive = {
      enable = true;
      ppfeaturemask = "0xfffd7fff";
    };

    # ──── Overlay & post-processing config selection ────
    environment.sessionVariables = {
      MANGOHUD = "1";
      MANGOHUD_CONFIGFILE = "${mangoHudConf}";
    };

    # ──── Hardware ────
    hardware.steam-hardware.enable = true;
    services.udev.packages = [ pkgs.game-devices-udev-rules ];

    # ──── Packages ────
    environment.systemPackages = with pkgs; [
      # Launchers
      heroic              # GOG & Epic

      # MangoHud
      mangohud

      # Vulkan
      vulkan-tools        # vkcube: minimal known-good overlay canary

      # Monitoring & profiling
      lm_sensors
      nvtopPackages.amd
      stress-ng
      s-tui
    ];
  };
}