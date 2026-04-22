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

				input.keyboard.xkb = {
					layout = "fr";
					variant = "afnor";
				};

				input.touchpad = {
					natural-scroll = null;
					tap = null;
				};

				window-rule = {
					geometry-corner-radius = 20;
					clip-to-geometry = true;
				};

				binds = { 
					"Mod+Return".spawn = lib.getExe pkgs.kitty;

					"Mod+Q".close-window = null;
					"Mod+F".maximize-column = null;
					"Mod+G".fullscreen-window = null;

					"Mod+H".focus-column-left = null;
					"Mod+L".focus-column-right = null;
					"Mod+K".focus-window-up = null;
					"Mod+J".focus-window-down = null;

					"Mod+Shift+H".move-column-left = null;
					"Mod+Shift+L".move-column-right = null;
					"Mod+Shift+K".move-window-up = null;
					"Mod+Shift+J".move-window-down = null;

					"Mod+S".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
				};

				debug = {
					honor-xdg-activation-with-invalid-serial = true;
				};
			};
		};
	};
}

