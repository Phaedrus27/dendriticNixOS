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

        # DNS confinement. NetworkNamespacePath joins the netns but (unlike
        # `ip netns exec`) does NOT overlay /etc/netns/vpn/resolv.conf, so
        # the unit would see the host's 127.0.0.53 stub — unreachable here.
        # Bind the tunnel resolver (10.2.0.1, ProtonVPN) in explicitly:
        BindReadOnlyPaths = [ "/etc/netns/vpn/resolv.conf:/etc/resolv.conf" ];

        # glibc bypasses netns DNS confinement via host unix sockets
        # (nscd/nsncd, systemd-resolved varlink) — sockets aren't network-
        # namespaced, so tracker lookups were leaking to LAN DNS (pihole →
        # cloudflare) outside the tunnel. Blocking them forces in-process
        # resolution via the resolv.conf bound above. '-' = tolerate absence.
        InaccessiblePaths = [ "-/run/nscd" "-/run/systemd/resolve" ];
      };
    };
  };
}