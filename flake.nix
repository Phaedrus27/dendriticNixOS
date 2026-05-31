{
  inputs = {
    # Core NixOS package set — unstable for latest packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake composition framework — splits flake outputs across modules
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Recursively imports all .nix files under ./modules — powers dendritic structure
    import-tree.url = "github:vic/import-tree";

    # Declarative wrappers for niri, alacritty, noctalia etc.
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    # Declarative secret management via age/YubiKey
    sops-nix.url = "github:Mic92/sops-nix";

    # Declarative disk partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs"; # avoid duplicate nixpkgs in lockfile
    
    # Hardware-specific NixOS modules (Framework 13 AMD profile for mew)
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake
    { inherit inputs; }
    (inputs.import-tree ./modules);
}