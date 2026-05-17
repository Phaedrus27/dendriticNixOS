{ self, inputs, ... }: {
  flake.nixosModules.arr = { pkgs, ... }: {

    users.groups.media = {};

    users.users.sonarr.extraGroups = [ "media" ];
    users.users.radarr.extraGroups = [ "media" ];
    users.users.prowlarr.extraGroups = [ "media" ];
    users.users.bazarr.extraGroups = [ "media" ];

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