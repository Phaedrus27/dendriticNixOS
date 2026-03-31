{ self, inputs, ... }: {

  flake.nixosConfigurations.mew = inputs.nixpkgs.lib.nixosSystem {
    modules = [ 
      self.nixosModules.mewConfiguration
    ];
  };

}