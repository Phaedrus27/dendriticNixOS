{ self, inputs, ... }: {

  flake.nixosConfigurations.squirtle = inputs.nixpkgs.lib.nixosSystem {
    modules = [ 
      self.nixosModules.squirtleConfiguration
    ];
  };

}