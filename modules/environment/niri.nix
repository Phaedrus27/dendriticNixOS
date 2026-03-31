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
				# spawn-at-startup = [
					# (lib.getExe self'.packages.myNoctalia)
				# ];

				xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

				input.keyboard.xkb = {
					layout = "fr";
					variant = "afnor";
				};

				window-rule = {
					geometry-corner-radius = 20;
					clip-to-geometry = true;
				};

				binds = { 
					"Mod+Return".spawn = lib.getExe pkgs.kitty;
					"Mod+Q".close-window = null;
				};

				debug = {
					honor-xdg-activation-with-invalid-serial = true;
				};
			};
		};
	};
}

