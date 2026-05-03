{ self, inputs, ... }: {
  flake.nixosModules.arr = { pkgs, ... }: {

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