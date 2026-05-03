{ self, inputs, ... }: {
  flake.nixosModules.qbittorrent = { pkgs, ... }: {

    environment.systemPackages = [ pkgs.qbittorrent-nox ];

    users.users.qbittorrent = {
      isSystemUser = true;
      group = "qbittorrent";
      home = "/var/lib/qbittorrent";
      createHome = true;
    };

    users.groups.qbittorrent = {};

    systemd.services.qbittorrent = {
      description = "qBittorrent in VPN namespace";
      after = [ "wg-vpn.service" ];
      requires = [ "wg-vpn.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "qbittorrent";
        Group = "qbittorrent";
        NetworkNamespacePath = "/run/netns/vpn";
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=8080";
        Restart = "on-failure";
      };
    };
  };
}