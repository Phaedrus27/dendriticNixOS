{ self, inputs, ... }: {
  flake.nixosModules.niri = { pkgs, lib, ... }: {
    programs.niri = {
      enable = true;
      package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };
  };

  flake.nixosModules.charizardNiri = { pkgs, lib, ... }: {
    programs.niri.package = lib.mkForce self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriCharizard;
  };

  flake.nixosModules.mewNiri = { pkgs, lib, ... }: {
    programs.niri.package = lib.mkForce self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriMew;
  };

  perSystem = { pkgs, lib, self', ... }:
    let

      # Flip to false to fall back to niri's built-in animations.
      useCachyAnimations = true;

      cachyAnimations = {
        workspace-switch.spring = _: { props = { damping-ratio = 1.0; stiffness = 1000; epsilon = 0.0001; }; };
        window-open  = { duration-ms = 200; curve = "ease-out-quad"; };
        window-close = { duration-ms = 200; curve = "ease-out-cubic"; };
        horizontal-view-movement.spring = _: { props = { damping-ratio = 1.0; stiffness = 900; epsilon = 0.0001; }; };
        window-movement.spring = _: { props = { damping-ratio = 1.0; stiffness = 800; epsilon = 0.0001; }; };
        window-resize.spring   = _: { props = { damping-ratio = 1.0; stiffness = 1000; epsilon = 0.0001; }; };
        config-notification-open-close.spring = _: { props = { damping-ratio = 0.6; stiffness = 1200; epsilon = 0.001; }; };
        screenshot-ui-open = { duration-ms = 300; curve = "ease-out-quad"; };
        overview-open-close.spring = _: { props = { damping-ratio = 1.0; stiffness = 900; epsilon = 0.0001; }; };
      };

      commonSettings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.myNoctalia)
          # Lock before the system sleeps. Run as a niri child so it inherits
          # the Wayland session, takes a logind sleep inhibitor, and runs the
          # proven lock IPC; -w waits so the lock paints before suspend.
          [
            (lib.getExe pkgs.swayidle)
            "-w"
            "before-sleep"
            "${lib.getExe self'.packages.myNoctalia} ipc call lockScreen lock"
          ]
        ];

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        # Toolkit hints for the Wayland session. niri exports these to every
        # process it spawns, so they cover the whole greetd -> niri-session tree.
        environment = {
          # Qt: prefer the Wayland backend, fall back to X11 (xcb) if a Qt app
          # lacks the wayland plugin — fallback rather than failing to launch.
          QT_QPA_PLATFORM = "wayland;xcb";
          # Qt-side counterpart to prefer-no-csd: suppress Qt-drawn titlebars.
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          # Electron/Chromium (VS Code, Discord, …) auto-pick Wayland rendering.
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
        };

        hotkey-overlay = {
          skip-at-startup = {};
          hide-not-bound = {};   # the curated-list switch from earlier
        };

        prefer-no-csd = {};

        input = {
          keyboard = {
            xkb = {
              layout = "fr,us";
              variant = "afnor";
            };
            numlock = {};
          };
          touchpad = {
            natural-scroll = {};
            tap = {};
          };
          focus-follows-mouse = _: { props.max-scroll-amount = "0%"; };
        };

        window-rules = [
          {
            geometry-corner-radius = 20;
            clip-to-geometry = true;
            shadow.on = {};
          }
          # Steam: float its child/popup windows, but keep the main client tiled.
          {
            matches = [ { app-id = "steam"; } ];
            excludes = [ { title = "^[Ss]team$"; } ];
            open-floating = true;
          }
          # Steam: pin notification toasts to the bottom-right, without stealing focus.
          {
            matches = [ { app-id = "steam"; title = "^notificationtoasts_\\d+_desktop$"; } ];
            default-floating-position = _: { props = { x = 10; y = 10; relative-to = "bottom-right"; }; };
            open-focused = false;
          }
        ];

        gestures = [
          {
            hot-corners.off = {};
          }
        ];

        binds = {
          # Hotkey overlay
          "Mod+Shift+Escape".show-hotkey-overlay = {};

          # Layout toggle
          "Mod+Shift+K".switch-layout = "next";

          # Applications
          "Mod+Return" = _: {
            props.hotkey-overlay-title = "Terminal";
            content.spawn-sh = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.myAlacritty;
          };
          "Mod+Space" = _: {
            props.hotkey-overlay-title = "Application Launcher";
            content.spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
          };
          "Mod+B" = _: {
            props.hotkey-overlay-title = "Browser";
            content.spawn = "firefox";
          };
          "Mod+E" = _: {
            props.hotkey-overlay-title = "File Manager";
            content.spawn = "nautilus";
          };
          "Mod+Alt+L" = _: {
            props.allow-inhibiting = false;
            props.hotkey-overlay-title = "Lock Screen";
            content.spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call lockScreen lock";
          };
          "Mod+Shift+Q" = _: {
            props.hotkey-overlay-title = "Session Menu";
            content.spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call sessionMenu toggle";
          };

          # Window focus
          "Mod+Q".close-window = {};
          "Mod+Left".focus-column-left = {};
          "Mod+H".focus-column-left = {};
          "Mod+Right".focus-column-right = {};
          "Mod+L".focus-column-right = {};
          "Mod+Up".focus-window-up = {};                       # arrows: strict within-column
          "Mod+Down".focus-window-down = {};
          "Mod+J".focus-window-or-workspace-down = {};         # J/K: within-column, then cross at edge
          "Mod+K".focus-window-or-workspace-up = {};
          "Mod+U".focus-workspace-down = {};                   # U/I: pure workspace jump (ex-PgDn/PgUp)
          "Mod+I".focus-workspace-up = {};
          "Mod+Home".focus-column-first = {};
          "Mod+End".focus-column-last = {};

          # Move windows
          "Mod+Ctrl+Left".move-column-left = {};
          "Mod+Ctrl+H".move-column-left = {};
          "Mod+Ctrl+Right".move-column-right = {};
          "Mod+Ctrl+L".move-column-right = {};
          "Mod+Ctrl+Up".move-window-up = {};
          "Mod+Ctrl+Down".move-window-down = {};
          "Mod+Ctrl+J".move-window-down-or-to-workspace-down = {};
          "Mod+Ctrl+K".move-window-up-or-to-workspace-up = {};
          "Mod+Ctrl+U".move-column-to-workspace-down = {};
          "Mod+Ctrl+I".move-column-to-workspace-up = {};
          "Mod+Ctrl+colon".move-column-to-monitor-left = {};
          "Mod+Ctrl+semicolon".move-column-to-monitor-right = {};
          "Mod+Ctrl+Home".move-column-to-first = {};
          "Mod+Ctrl+End".move-column-to-last = {};

          # Monitor focus
          "Mod+Shift+Left".focus-monitor-left = {};
          "Mod+Shift+Right".focus-monitor-right = {};
          "Mod+Shift+Up".focus-monitor-up = {};
          "Mod+Shift+Down".focus-monitor-down = {};
          "Mod+colon".focus-monitor-left = {};
          "Mod+semicolon".focus-monitor-right = {};

          # Workspace scroll
          "Mod+WheelScrollDown".focus-workspace-down = {};
          "Mod+WheelScrollUp".focus-workspace-up = {};
          "Mod+Ctrl+WheelScrollDown".move-column-to-workspace-down = {};
          "Mod+Ctrl+WheelScrollUp".move-column-to-workspace-up = {};
          "Mod+WheelScrollRight".focus-column-right = {};
          "Mod+WheelScrollLeft".focus-column-left = {};
          "Mod+Ctrl+WheelScrollRight".move-column-right = {};
          "Mod+Ctrl+WheelScrollLeft".move-column-left = {};

          # Layout
          "Mod+Ctrl+F".expand-column-to-available-width = {};
          "Mod+C".center-column = {};
          "Mod+Ctrl+C".center-visible-columns = {};
          "Mod+Minus".set-column-width = "-10%";
          "Mod+plus".set-column-width = "+10%";
          "Mod+slash".set-window-height = "-10%";
          "Mod+asterisk".set-window-height = "+10%";
          "Mod+R".switch-preset-column-width = {};
          "Mod+Shift+R".switch-preset-column-width-back = {};   # reverse cycle (optional)

          # Modes
          "Mod+T".toggle-window-floating = {};
          "Mod+F".fullscreen-window = {};
          "Mod+Z".toggle-column-tabbed-display = {};

          # Screenshots
          "Mod+Shift+S" = _: {
            props.hotkey-overlay-title = "Screenshot (full)";
            content.spawn-sh = "screenshot-full";
          };
          "Mod+S" = _: {
            props.hotkey-overlay-title = "Screenshot (region)";
            content.spawn-sh = "screenshot-region";
          };

          # Escape / power
          "Mod+Escape".toggle-keyboard-shortcuts-inhibit = {};
          "Ctrl+Alt+Delete".quit = {};
          "Mod+Shift+P".power-off-monitors = {};
          "Mod+O".toggle-overview = {};
        };

        layout = {
          background-color = "transparent";
          focus-ring.off = {};
          gaps = 16;
          preset-column-widths = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];
          struts = {};

          tab-indicator = {
            hide-when-single-tab = {};
            place-within-column = {};
            position = "top";
            width = 4;
            gap = 6;
            gaps-between-tabs = 4;
            corner-radius = 4;
            length = _: { props.total-proportion = 1.0; };
            active-color = "#7fc8ff";
            inactive-color = "#505050";
          };
        };

        # layout: DELETE the background-color line (Option 1 doesn't use it —
        # the sharp wallpaper should render on workspaces normally)

        layer-rules = [
          {
            matches = [ { namespace = "^noctalia-wallpaper"; } ];   # was ^noctalia-wallpaper
            place-within-backdrop = true;
          }
        ];

        debug = {
          honor-xdg-activation-with-invalid-serial = true;
          };
          } // lib.optionalAttrs useCachyAnimations {
            animations = cachyAnimations;
          };
    in
    {
      packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = commonSettings;
      };

      packages.myNiriCharizard = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
          settings = commonSettings // {
            outputs = {
              "DP-1" = {
                mode = "2560x1440@239.970";
                scale = 1.0;
                position = _: { props = { x = 0; y = 620; }; };
                variable-refresh-rate = _: {};
              };
              "HDMI-A-1" = {
                mode = "2560x2880@59.967";
                scale = 1.25;
                position = _: { props = { x = 2560; y = 0; }; };
              };
            };
          };
      };

      packages.myNiriMew = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = commonSettings // {
          extraConfig = ''
            output "eDP-1" {
              mode "2256x1504@60"
              position x=0 y=0
              scale 1.5
            }
          '';
        };
      };
    };
}