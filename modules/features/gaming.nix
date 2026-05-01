{self, inputs, ... }: {
    flake.nixosModules.gaming = {pkgs, lib, ... }: {
        programs.steam.enable = true;
        programs.protontricks.enable = true;
    };
}