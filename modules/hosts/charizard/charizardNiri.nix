{ self, inputs, ... }: {
	flake.nixosModules.charizardNiri = { pkgs, lib, ... }: {
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

				output = [
					{
						name = "HDMI-A-1";
						layout = {
							rows = 2;
							columns = 1;
							preset-column-widths = {
								proportion = 0.5;
							};
						};
					}
				];

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
					"Mod+Return".spawn-sh = lib.getExe pkgs.kitty;
					"Mod+Return".hotkey-overlay.title = "Kitty";

					"Mod+Q".close-window = {};
					"Mod+F".maximize-column = {};
					"Mod+G".fullscreen-window = {};

					"Mod+Tab".toggle-overview = {};

					"Mod+WheelScrollRight".focus-column-right = {};
					"Mod+WheelScrollLeft".focus-column-left = {};

					"Mod+Left".focus-column-left = {};
   					"Mod+Right".focus-column-right = {};
    				"Mod+Down".focus-workspace-down = {};
    				"Mod+Up".focus-workspace-up = {};

    				"Mod+Shift+Left".move-column-left = {};
    				"Mod+Shift+Right".move-column-right = {};
    				"Mod+Shift+Down".move-column-to-workspace-down = {};
    				"Mod+Shift+Up".move-column-to-workspace-up = {};

					"Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
					"Mod+Space".hotkey-overlay.title = "Launcher";
				};


				layout = {
					focus-ring.off = {};
					gaps = 4;
					struts = {
						top = 4;
						bottom = 4;
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

