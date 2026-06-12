{ self, inputs, ... }: {
  flake.nixosModules.jellyfin = { pkgs, ... }: {

    services.jellyfin = {
      enable = true;
      openFirewall = false;
      dataDir = "/var/lib/jellyfin";
    };

    users.users.jellyfin.extraGroups = [ "media" "video" "render" ];

    # Intel Quick Sync
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        vpl-gpu-rt
      ];
    };

    dendriticNixOS.monitoring.watchedServices = [ "jellyfin" ];
  };
}