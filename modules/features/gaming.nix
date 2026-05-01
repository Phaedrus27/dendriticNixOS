{self, inputs, ... }: {
    flake.nixosModules.gaming = {pkgs, lib, ... }: {
        programs.steam.enable = true;
        programs.steam.protontricks.enable = true;

        environment.systemPackages = [
            
        ];
    };
}