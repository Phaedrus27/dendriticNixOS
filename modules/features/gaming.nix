{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, config, ... }: {

    programs.steam = {
      enable = true;
      protontricks.enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    programs.gamescope.enable = true;

    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };

    hardware.steam-hardware.enable = true;

    hardware.amdgpu.amdvlk = {
      enable = true;
      support32Bit.enable = true;
    };

    environment.systemPackages = with pkgs; [
      mangohud
      lutris
      heroic
    ];

  };
}