{ self, inputs, ... }: {

  flake.nixosConfigurations.charizard = inputs.nixpkgs.lib.nixosSystem {
    modules = [ 
      self.nixosModules.charizardConfiguration
    ];
  };

}