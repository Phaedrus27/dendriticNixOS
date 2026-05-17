{ self, inputs, ... }: {
  flake.nixosModules.flaresolverr = { pkgs, ... }: {

    users.users.flaresolverr = {
      isSystemUser = true;
      group = "flaresolverr";
      home = "/var/lib/flaresolverr";
      createHome = true;
    };
    users.groups.flaresolverr = {};

    systemd.services.flaresolverr = {
      description = "FlareSolverr in VPN namespace";
      after = [ "wg-vpn.service" ];
      requires = [ "wg-vpn.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "8191";
        LOG_LEVEL = "info";
      };
      serviceConfig = {
        Type = "simple";
        User = "flaresolverr";
        Group = "flaresolverr";
        NetworkNamespacePath = "/run/netns/vpn";
        ExecStart = "${pkgs.flaresolverr}/bin/flaresolverr";
      };
    };

  };
}