{ self, inputs, ... }: {
  flake.nixosModules.jellyfin = { pkgs, ... }: {

    services.jellyfin = {
      enable = true;
      openFirewall = false;
      dataDir = "/var/lib/jellyfin";
    };

    # Give jellyfin access to media
    users.users.jellyfin.extraGroups = [ "radarr" "sonarr" ];

  };
}