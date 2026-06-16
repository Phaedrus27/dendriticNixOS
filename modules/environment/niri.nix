{ self, inputs, ... }: {
  # ════════════════════════════════════════════════════════════════════════
  #  niri — workstation-agnostic base
  #
  #  Owns: the base `niri` NixOS module, the shared `commonSettings` attrset,
  #  the `myNiri` package, and the `niriCommonSettings` export.
  #
  #  Host-specific output / VRR / per-host binds live elsewhere and consume
  #  `niriCommonSettings`:
  #    modules/hosts/charizard/charizardNiri.nix   (myNiriCharizard, charizardNiri)
  #    modules/hosts/mew/mewNiri.nix               (myNiriMew, mewNiri)
  # ════════════════════════════════════════════════════════════════════════

  flake.nixosModules.niri = { pkgs, lib, ... }: {
    programs.niri = {
      enable = true;
      package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };

    # Cursor theme must be installed AND set session-wide, or niri and the
    # XWayland/GTK clients fall back and fail to load cursor icons.
    environment.systemPackages = [ pkgs.bibata-cursors ];
    environment.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
    };
  };

  perSystem = { pkgs, lib, self', ... }:
    let
      # Animations: flip to false to fall back to niri's built-in set.
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

      # ══════════════════════════════════════════════════════════════════
      #  commonSettings — host-agnostic niri config (one attrset → wrapper)
      #  Sections, in order:
      #    1. Startup / session   spawn-at-startup, xwayland, environment
      #    2. Input               keyboard, touchpad, pointer
      #    3. Window rules        catch-all look + Steam quirks
      #    4. Appearance          cursor, csd, overlay, gestures, layout, layers
      #    5. Keybinds            (sub-headers within)
      #    6. Debug
      #    7. Animations          appended when useCachyAnimations
      # ══════════════════════════════════════════════════════════════════
      commonSettings = {

        # ────────────────────────────  Startup / session  ────────────────────────────
        spawn-at-startup = [
          (lib.getExe self'.packages.myNoctalia)
          # Lock before the system sleeps: run as a niri child so it inherits the
          # Wayland session and holds a logind sleep inhibitor; -w waits so the
          # lock paints before suspend.
          [
            (lib.getExe pkgs.swayidle)
            "-w"
            "before-sleep"
            "${lib.getExe self'.packages.myNoctalia} ipc call lockScreen lock"
          ]
        ];

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        # Toolkit hints exported to every process niri spawns (the whole
        # greetd -> niri-session tree).
        environment = {
          # Prefer the Qt Wayland backend; fall back to X11 rather than fail to launch.
          QT_QPA_PLATFORM = "wayland;xcb";
          # Qt counterpart to prefer-no-csd: suppress Qt-drawn titlebars.
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          # Electron/Chromium (VS Code, Discord, …) pick Wayland rendering automatically.
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
        };

        # ────────────────────────────  Input  ────────────────────────────
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
          # Focus follows the pointer, but never auto-scrolls the view to reach it.
          focus-follows-mouse = _: { props.max-scroll-amount = "0%"; };
        };

        # ────────────────────────────  Window rules  ────────────────────────────
        window-rules = [
          # Rounded + clipped corners with a drop shadow on every window.
          {
            geometry-corner-radius = 20;
            clip-to-geometry = true;
            shadow.on = {};
          }
          # Steam: float its child/popup windows, keep the main client tiled.
          {
            matches = [ { app-id = "steam"; } ];
            excludes = [ { title = "^[Ss]team$"; } ];
            open-floating = true;
          }
          # Steam: pin notification toasts bottom-right, without stealing focus.
          {
            matches = [ { app-id = "steam"; title = "^notificationtoasts_\\d+_desktop$"; } ];
            default-floating-position = _: { props = { x = 10; y = 10; relative-to = "bottom-right"; }; };
            open-focused = false;
          }
        ];

        # ────────────────────────────  Appearance  ────────────────────────────
        cursor = {
          xcursor-theme = "Bibata-Modern-Classic";
          xcursor-size = 24;
        };

        # Ask clients to drop their own decorations (no server-side titlebar in a tiler).
        prefer-no-csd = {};

        hotkey-overlay = {
          skip-at-startup = {};   # don't pop the overlay on every launch
          hide-not-bound = {};    # hide actions not bound to any key
        };

        gestures = [
          { hot-corners.off = {}; }   # no top-left overview hot corner
        ];

        layout = {
          background-color = "transparent";   # let Noctalia's backdrop wallpaper show through
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
            # Explicit colours: focus-ring and border are both off, so there's
            # nothing for the indicator to inherit a colour from.
            active-color = "#7fc8ff";
            inactive-color = "#505050";
          };
        };

        # Put Noctalia's wallpaper surface into niri's backdrop (visible in the
        # overview and behind transparent windows). Pairs with the transparent
        # background-color above.
        layer-rules = [
          {
            matches = [ { namespace = "^noctalia-wallpaper"; } ];
            place-within-backdrop = true;
          }
        ];

        # ────────────────────────────  Keybinds  ────────────────────────────
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
            props.allow-inhibiting = false;   # a fullscreen app can't swallow the lock combo
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
          "Mod+Up".focus-window-up = {};                 # arrows: strict within-column
          "Mod+Down".focus-window-down = {};
          "Mod+J".focus-window-or-workspace-down = {};   # J/K: within-column, then cross at the edge
          "Mod+K".focus-window-or-workspace-up = {};
          "Mod+U".focus-workspace-down = {};             # U/I: jump straight between workspaces
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
          "Mod+Ctrl+Minus".consume-or-expel-window-left = {};
          "Mod+Ctrl+Plus".consume-or-expel-window-right = {};

          # Monitor focus
          "Mod+Shift+Left".focus-monitor-left = {};
          "Mod+Shift+Right".focus-monitor-right = {};
          "Mod+Shift+Up".focus-monitor-up = {};
          "Mod+Shift+Down".focus-monitor-down = {};
          "Mod+colon".focus-monitor-left = {};
          "Mod+semicolon".focus-monitor-right = {};

          # Workspace / column scroll
          "Mod+WheelScrollDown".focus-workspace-down = {};
          "Mod+WheelScrollUp".focus-workspace-up = {};
          "Mod+Ctrl+WheelScrollDown".move-column-to-workspace-down = {};
          "Mod+Ctrl+WheelScrollUp".move-column-to-workspace-up = {};
          "Mod+WheelScrollRight".focus-column-right = {};
          "Mod+WheelScrollLeft".focus-column-left = {};
          "Mod+Ctrl+WheelScrollRight".move-column-right = {};
          "Mod+Ctrl+WheelScrollLeft".move-column-left = {};

          # Column width / window height / presets
          "Mod+Ctrl+F".expand-column-to-available-width = {};
          "Mod+C".center-column = {};
          "Mod+Ctrl+C".center-visible-columns = {};
          "Mod+apostrophe".set-column-width = "-10%";       # width down  (')
          "Mod+dead_circumflex".set-column-width = "+10%";  # width up    (^ dead key)
          "Mod+slash".set-window-height = "-10%";
          "Mod+asterisk".set-window-height = "+10%";
          "Mod+R".switch-preset-column-width = {};
          "Mod+Shift+R".switch-preset-column-width-back = {};   # reverse-cycle the presets

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

        # ────────────────────────────  Debug  ────────────────────────────
        debug = {
          honor-xdg-activation-with-invalid-serial = true;
        };

      } // lib.optionalAttrs useCachyAnimations {
        # ────────────────────────────  Animations  ────────────────────────────
        animations = cachyAnimations;
      };
    in
    {
      # Shared base, consumed by the per-host niri modules (charizard, mew).
      _module.args.niriCommonSettings = commonSettings;

      packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = commonSettings;
      };
    };
}
