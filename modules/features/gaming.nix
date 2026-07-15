{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, config, ... }:
  let
    # MangoHud + vkBasalt configs live in the Nix store and are selected via the
    # env vars further down — fully declarative, no ~/.config state to babysit.
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

    vkBasaltConf = pkgs.writeText "vkBasalt.conf" ''
      # Opt in per game with ENABLE_VKBASALT=1 %command%. Chain more with a
      # colon, e.g. effects = fxaa:cas. Home toggles in-game (XWayland only).
      effects = cas
      casSharpness = 0.4
      toggleKey = Home
      enableOnLaunch = True
    '';
  in {

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
    # programs.corectrl.enable handles the package, dbus, the corectrl group and
    # the no-password polkit rule. overdrive.enable sets ppfeaturemask to the
    # flicker-safe 0xfffd7fff — left there on purpose given DP-1's flicker
    # sensitivity. (corectrl only enforces profiles while running — see the
    # spawn-at-startup line in charizardNiri to apply them at login.)
    programs.corectrl.enable = true;
    hardware.amdgpu.overdrive.enable = true;

    # ── Game streaming (Sunshine host) ───────────────────────────────────────
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;       # required for KMS capture under Wayland/niri
      openFirewall = true;
      settings.sunshine_name = "charizard";
      applications.apps = [
        {
          name = "Steam Big Picture";
          # capSysAdmin runs these as root; drop back to phaedrus to reach the
          # real Wayland session and the user's Steam.
          detached = [ "setsid sudo -u phaedrus steam steam://open/bigpicture" ];
          "prep-cmd" = [
            { do = ""; undo = "sudo -u phaedrus setsid steam steam://close/bigpicture"; }
          ];
          "image-path" = "steam.png";
        }
      ];
    };

    # Virtual input for Moonlight clients (group + udev perms + module). Without
    # group membership you get video but no remote keyboard/mouse.
    hardware.uinput.enable = true;

    # ── Overlay & post-processing config selection ───────────────────────────
    environment.sessionVariables = {
      MANGOHUD = "1";
      MANGOHUD_CONFIGFILE = "${mangoHudConf}";
      VKBASALT_CONFIG_FILE = "${vkBasaltConf}";
    };

    # ── Hardware ─────────────────────────────────────────────────────────────
    hardware.steam-hardware.enable = true;
    services.udev.packages = [ pkgs.game-devices-udev-rules ];
    users.users.phaedrus.extraGroups = [ "corectrl" "uinput" ];

    # ── Packages ─────────────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      # Launchers
      heroic              # GOG & Epic

      # MangoHud & overlay
      mangohud
      goverlay            # MangoHud GUI config

      # Vulkan
      vkbasalt            # post-processing layer (sharpening, AA)
      vulkan-tools        # vkcube: minimal known-good overlay canary

      # Monitoring & profiling
      lm_sensors
      nvtopPackages.amd
      stress-ng
      s-tui
    ];
  };
}