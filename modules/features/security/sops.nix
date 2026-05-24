{ self, inputs, ... }: {
  flake.nixosModules.sops = { pkgs, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    environment.systemPackages = [ pkgs.sops pkgs.age ];
  };
}