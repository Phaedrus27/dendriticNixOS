{
  inputs = {
    # Core NixOS package set — unstable for latest packages.
    # Inputs that consume nixpkgs follow this one, so the fleet evaluates a
    # single revision rather than one per input.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake composition framework — splits flake outputs across modules
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Recursively imports all .nix files under ./modules — powers dendritic structure
    import-tree.url = "github:vic/import-tree";

    # Declarative wrappers for niri, alacritty, noctalia etc.
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    wrapper-modules.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative secret management via age/YubiKey
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative disk partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware-specific NixOS modules (Framework 13 AMD profile for mew).
    # Ships modules rather than packages, so its nixpkgs never builds anything
    # here and is deliberately left unpinned.
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Vendor kernel/firmware + declarative config.txt for pidgey (Pi 5).
    # Pinned to a release tag: single-maintainer flake, so upgrades are
    # deliberate lockfile bumps, not silent channel drift. Its nixpkgs is
    # left alone — the vendor kernel is built against the revision this flake
    # pins, and overriding it risks a Pi that won't boot.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/v1.20260517.0";
  };