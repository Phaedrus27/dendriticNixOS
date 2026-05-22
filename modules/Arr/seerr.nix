{ self, inputs, ... }: {
  flake.nixosModules.seerr = { config, pkgs, ... }: {

    users.users.seerr = {
      isSystemUser = true;
      group = "seerr";
      home = "/var/lib/seerr";
      createHome = true;
    };
    users.groups.seerr = {};

    systemd.services.seerr = {
      description = "Seerr - Media Request Management";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        NODE_ENV = "production";
        CONFIG_DIRECTORY = "/var/lib/seerr";
        PORT = "5055";
      };
      serviceConfig = {
        Type = "simple";
        User = "seerr";
        Group = "seerr";
        ExecStart = "${pkgs.seerr}/bin/seerr";
        Restart = "on-failure";
      };
    };

  };
}