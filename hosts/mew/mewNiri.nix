{ self, inputs, ... }: {
  perSystem = { pkgs, lib, self', niriCommonSettings, ... }: {
    packages.myNiriMew = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = lib.recursiveUpdate niriCommonSettings {
        outputs = {
          "eDP-1" = {
            mode = "2256x1504@60";
            scale = 1.5;
            position = _: { props = { x = 0; y = 0; }; };
          };
        };
      };
    };
  };

  flake.nixosModules.mewNiri = { pkgs, lib, ... }: {
    programs.niri.package =
      lib.mkForce self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriMew;
  };
}