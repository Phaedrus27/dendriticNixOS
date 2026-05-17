{ self, inputs, ... }: {
  flake.nixosModules.arr = { pkgs, ... }: {

    users.groups.media = {};

    users.groups.prowlarr = {};
    users.users.prowlarr = {
      isSystemUser = true;
      group = "prowlarr";
      extraGroups = [ "media" ];
    };

    users.groups.sonarr = {};
    users.users.sonarr = {
      isSystemUser = true;
      group = "sonarr";
      extraGroups = [ "media" ];
    };

    users.groups.radarr = {};
    users.users.radarr = {
      isSystemUser = true;
      group = "radarr";
      extraGroups = [ "media" ];
    };

    users.groups.bazarr = {};
    users.users.bazarr = {
      isSystemUser = true;
      group = "bazarr";
      extraGroups = [ "media" ];
    };

    services.prowlarr = {
      enable = true;
      openFirewall = false;
    };
    services.sonarr = {
      enable = true;
      openFirewall = false;
      dataDir = "/var/lib/sonarr";
    };
    services.radarr = {
      enable = true;
      openFirewall = false;
      dataDir = "/var/lib/radarr";
    };
    services.bazarr = {
      enable = true;
      openFirewall = false;
    };
  };
}