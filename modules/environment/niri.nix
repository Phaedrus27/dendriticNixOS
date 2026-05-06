{ self, inputs, ... }: {
	flake.nixosModules.niri = { pkgs, lib, ... }: {
		programs.niri = {
			enable = true;
			package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
		};
	};

	perSystem = { pkgs, lib, self', ... }: {
		packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
			inherit pkgs;
			settings = {
				 spawn-at-startup = [
					 (lib.getExe self'.packages.myNoctalia)
				 ];

				xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

				input = {
				
					keyboard.xkb = {
						layout = "fr";
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

				outputs = {
					"DP-1" = {
						mode = "2560x1440";
      			scale = 1.0;
					};

					"HDMI-A-1" = {
      			mode = "2560x2880";
      			scale = 1.0;
					};
				};

				gestures = [
					{
						hot-corners.off = {};
					}
				];

				settings.workspaces = [
					{ name = "1"; }
					{ name = "2"; }
					{ name = "3"; }
					{ name = "4"; }
					{ name = "5"; }
					{ name = "6"; }
				];
				

				binds = { 
					# Hotkey overlay
					"Mod+Shift+Escape".show-hotkey-overlay = {};

					# Applications
					"Mod+Return" = {
						hotkey-overlay-title = "Open Terminal: Alacritty";
						spawn-sh = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.myAlacritty;
					};
					"Mod+Space" = {
						hotkey-overlay-title = "Open App Launcher";
						spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
					};
					"Mod+B" = {
						hotkey-overlay-title = "Open Browser: Firefox";
						spawn = "firefox";
					};
					"Mod+E" = {
						hotkey-overlay-title = "File Manager: Nautilus";
						spawn = "nautilus";
					};
					"Mod+Alt+L" = {
						hotkey-overlay-title = "Lock Screen";
						spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call lockScreen lock";
					};
					"Mod+Shift+Q" = {
						hotkey-overlay-title = "Session Menu";
						spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call sessionMenu toggle";
					};

					# Window focus
  				"Mod+Q".close-window = {};
					"Mod+Left".focus-column-left = {};
					"Mod+H".focus-column-left = {};
					"Mod+Right".focus-column-right = {};
					"Mod+L".focus-column-right = {};
					"Mod+Up".focus-window-up = {};
					"Mod+K".focus-window-up = {};
					"Mod+Down".focus-window-down = {};
					"Mod+J".focus-window-down = {};
					"Mod+Home".focus-column-first = {};
					"Mod+End".focus-column-last = {};

					# Move windows
					"Mod+Ctrl+Left".move-column-left = {};
					"Mod+Ctrl+H".move-column-left = {};
					"Mod+Ctrl+Right".move-column-right = {};
					"Mod+Ctrl+L".move-column-right = {};
					"Mod+Ctrl+Up".move-window-up = {};
					"Mod+Ctrl+K".move-window-up = {};
					"Mod+Ctrl+Down".move-window-down = {};
					"Mod+Ctrl+J".move-window-down = {};
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
					"Mod+WheelScrollDown" = { cooldown-ms = 150; focus-workspace-down = {}; };
					"Mod+WheelScrollUp" = { cooldown-ms = 150; focus-workspace-up = {}; };
					"Mod+Ctrl+WheelScrollDown" = { cooldown-ms = 150; move-column-to-workspace-down = {}; };
					"Mod+Ctrl+WheelScrollUp" = { cooldown-ms = 150; move-column-to-workspace-up = {}; };
					"Mod+WheelScrollRight".focus-column-right = {};
					"Mod+WheelScrollLeft".focus-column-left = {};
					"Mod+Ctrl+WheelScrollRight".move-column-right = {};
					"Mod+Ctrl+WheelScrollLeft".move-column-left = {};

					# Layout
					"Mod+Ctrl+F".expand-column-to-available-width = {};
					"Mod+C".center-column = {};
					"Mod+Ctrl+C".center-visible-columns = {};
					"Mod+Minus".set-column-width = "-10%";
					"Mod+equal".set-column-width = "+10%";
					"Mod+Shift+Minus".set-window-height = "-10%";
					"Mod+Shift+equal".set-window-height = "+10%";

					# Modes
					"Mod+T".toggle-window-floating = {};
					"Mod+F".fullscreen-window = {};
					"Mod+W".toggle-column-tabbed-display = {};

					# Screenshots
					"Ctrl+Shift+1".screenshot = {};
					"Ctrl+Shift+2".screenshot-screen = {};
					"Ctrl+Shift+3".screenshot-window = {};

					# Escape / power
					"Mod+Escape" = { allow-inhibiting = false; toggle-keyboard-shortcuts-inhibit = {}; };
					"Ctrl+Alt+Delete".quit = {};
					"Mod+Shift+P".power-off-monitors = {};
					"Mod+O" = { repeat = false; toggle-overview = {}; };

					# Workspace switching — unshifted keys on AFNOR
					"Mod+agrave".focus-workspace = "1";
					"Mod+eacute".focus-workspace = "2";
					"Mod+egrave".focus-workspace = "3";
					"Mod+ecircumflex".focus-workspace = "4";
					"Mod+parenleft".focus-workspace = "5";
					"Mod+parenright".focus-workspace = "6";

					"Mod+Ctrl+agrave".move-column-to-workspace = "1";
					"Mod+Ctrl+eacute".move-column-to-workspace = "2";
					"Mod+Ctrl+egrave".move-column-to-workspace = "3";
					"Mod+Ctrl+ecircumflex".move-column-to-workspace = "4";
					"Mod+Ctrl+parenleft".move-column-to-workspace = "5";
					"Mod+Ctrl+parenright".move-column-to-workspace = "6";
					};


				layout = {
					focus-ring.off = {};
					gaps = 16;
					struts = {
						top = 16;
						bottom = 16;
						left = 4;
						right = 4;
					};
				};

				debug = {
					honor-xdg-activation-with-invalid-serial = true;
				};
			};
		};
	};
}


