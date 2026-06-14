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

        input = {
          keyboard.xkb = {
            layout = "fr,us";
            variant = "afnor";
          };
          touchpad = {
            natural-scroll = {};
            tap = {};
          };
        };

        window-rules = [
          {
            geometry-corner-radius = 20;
            clip-to-geometry = true;
            shadow.on = {};
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
          "Mod+Return".spawn-sh = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.myAlacritty;
          "Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
          "Mod+B".spawn = "firefox";
          "Mod+E".spawn = "nautilus";
          "Mod+Alt+L" = _: {
            props.allow-inhibiting = false;
            content.spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call lockScreen lock";
          };
          "Mod+Shift+Q".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call sessionMenu toggle";

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
          "Mod+W".toggle-column-tabbed-display = {};

          # Screenshots
          "Mod+S".spawn-sh = "screenshot-full";
          "Mod+Shift+S".spawn-sh = "screenshot-region";

          # Escape / power
          "Mod+Escape".toggle-keyboard-shortcuts-inhibit = {};
          "Ctrl+Alt+Delete".quit = {};
          "Mod+Shift+P".power-off-monitors = {};
          "Mod+O".toggle-overview = {};
        };

        layout = {
          focus-ring.off = {};
          gaps = 8;
          preset-column-widths = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];
          struts = {
            top = 8;
            bottom = 8;
            left = 4;
            right = 4;
          };
        };

        debug = {
          honor-xdg-activation-with-invalid-serial = true;
        };
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
          extraConfig = ''
            output "DP-1" {
              mode "2560x1440@60"
              position x=0 y=620
              scale 1.0
            }
            output "HDMI-A-1" {
              mode "2560x2880@60"
              position x=2560 y=0
              scale 1.25
            }
          '';
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