{ self, inputs, ... }: {
	flake.nixosModules.Niri = { pkgs, lib, ... }: {
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
				

				binds = { 
					"Mod+Return".spawn-sh = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.myAlacritty;

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
					
					"Mod+h".focus-column-left = {};
 					"Mod+l".focus-column-right = {};
  					"Mod+k".focus-window-up = {};
  					"Mod+j".focus-window-down = {};

					"Mod+colon".focus-monitor-left = {};
  					"Mod+semicolon".focus-monitor-right = {};

					"Mod+equal".move-window-to-monitor-right = {};
  					"Mod+ellipsis".move-window-to-monitor-left = {};

					"Mod+Minus".set-column-width = "-10%";
          			"Mod+Plus".set-column-width = "+10%";
          			"Mod+Shift+Minus".set-window-height = "-10%";
          			"Mod+Shift+Plus".set-window-height = "+10%";

    				"Mod+Shift+Left".move-column-left = {};
    				"Mod+Shift+Right".move-column-right = {};
    				"Mod+Shift+Down".move-column-to-workspace-down = {};
    				"Mod+Shift+Up".move-column-to-workspace-up = {};

					"Mod+Shift+h".move-column-left = {};
  					"Mod+Shift+l".move-column-right = {};
  					"Mod+Shift+k".move-window-up = {};
  					"Mod+Shift+j".move-window-down = {};

					"Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
				};


				layout = {
					focus-ring.off = {};
					gaps = 16;
					struts = {
						top = 32;
						bottom = 32;
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


