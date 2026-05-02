{ self, inputs, ... }: {
  perSystem = { pkgs, ... }: {
    packages.myAlacritty = inputs.wrapper-modules.wrappedModules.alacritty.wrap {
      inherit pkgs;
      settings = {
        window = {
          opacity = 0.7;
          dimensions = {
            columns = 200;
            lines = 18;
          };
        };
      };
    };
  };
}