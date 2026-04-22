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
					"Mod+Shift+K".move-column-up = null;
					"Mod+Shift+J".move-column-down = null;

					"Mod+1".focus-workspace = "w0";
          "Mod+2".focus-workspace = "w1";
          "Mod+3".focus-workspace = "w2";
          "Mod+4".focus-workspace = "w3";
          "Mod+5".focus-workspace = "w4";
          "Mod+6".focus-workspace = "w5";
          "Mod+7".focus-workspace = "w6";
          "Mod+8".focus-workspace = "w7";
          "Mod+9".focus-workspace = "w8";
          "Mod+0".focus-workspace = "w9";

          "Mod+Shift+1".move-column-to-workspace = "w0";
          "Mod+Shift+2".move-column-to-workspace = "w1";
          "Mod+Shift+3".move-column-to-workspace = "w2";
          "Mod+Shift+4".move-column-to-workspace = "w3";
          "Mod+Shift+5".move-column-to-workspace = "w4";
          "Mod+Shift+6".move-column-to-workspace = "w5";
          "Mod+Shift+7".move-column-to-workspace = "w6";
          "Mod+Shift+8".move-column-to-workspace = "w7";
          "Mod+Shift+9".move-column-to-workspace = "w8";
          "Mod+Shift+0".move-column-to-workspace = "w9";

				};

				workspaces = let
					settings = {layout.gaps = 5;};
				in {
					"w0" = settings;
          "w1" = settings;
          "w2" = settings;
          "w3" = settings;
          "w4" = settings;
          "w5" = settings;
          "w6" = settings;
          "w7" = settings;
          "w8" = settings;
          "w9" = settings;
				};

				debug = {
					honor-xdg-activation-with-invalid-serial = true;
				};
			};
		};
	};
}

