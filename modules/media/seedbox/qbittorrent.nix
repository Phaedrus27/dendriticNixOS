{ self, inputs, ... }: {
  flake.nixosModules.qbittorrent = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.qbittorrent-nox ];

    users.users.qbittorrent = {
      isSystemUser = true;
      group = "qbittorrent";
      extraGroups = [ "media" ];
      home = "/var/lib/qbittorrent";
      createHome = true;
    };
    users.groups.qbittorrent = {};

    systemd.services.qbittorrent = {
      description = "qBittorrent in VPN namespace";
      after = [ "wg-vpn.service" "mnt-cache.mount" "mnt-storage.mount" ];
      requires = [ "wg-vpn.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "qbittorrent";
        Group = "media";        # files written as group media
        UMask = "0002";         # group-writable so arr services can read
        NetworkNamespacePath = "/run/netns/vpn";

        # DNS confinement, part 1: NetworkNamespacePath joins the netns but
        # (unlike `ip netns exec`) does NOT overlay /etc/netns/vpn/resolv.conf,
        # so the unit would see the host's 127.0.0.53 stub — unreachable
        # inside the netns. Bind the tunnel resolver (10.2.0.1, ProtonVPN)
        # over /etc/resolv.conf explicitly:
        BindReadOnlyPaths = [ "/etc/netns/vpn/resolv.conf:/etc/resolv.conf" ];

        # DNS confinement, part 2: glibc bypasses netns isolation for name
        # lookups via host unix sockets (nscd/nsncd, systemd-resolved
        # varlink) — unix sockets aren't network-namespaced, so tracker DNS
        # was leaking to LAN DNS (pihole → upstream) outside the tunnel.
        # Blocking the sockets forces in-process resolution via the
        # resolv.conf bound above. Leading '-' = tolerate absence.
        InaccessiblePaths = [ "-/run/nscd" "-/run/systemd/resolve" ];

        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=8080 --confirm-legal-notice";
      };
    };
  };
}