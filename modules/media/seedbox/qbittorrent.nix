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

    # WHY: the sandbox bind-mounts these paths at spawn; without an
    # explicit ordering dependency the unit races the (nofail, fuse)
    # mergerfs mount at boot and fails NAMESPACE — observed 2026-07-16
    # when new PCI enumeration slowed mount assembly.
    unitConfig.RequiresMountsFor = [ "/mnt/storage/downloads" "/mnt/cache/incomplete" ];

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

        # Sandboxing: qBittorrent's core function is parsing attacker-
        # controlled data (torrent metadata, peer wire protocol). Assume
        # eventual exploitation; scope what a compromise can touch.

        # Filesystem: whole OS read-only except state dir and the two
        # download trees (completed on storage, incomplete on cache —
        # completion is a cross-fs copy+delete, so both must be writable).
        # A wrong/missing path here fails loudly: EROFS in the journal.
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          "/var/lib/qbittorrent"
          "/mnt/storage/downloads"
          "/mnt/cache/incomplete"
        ];
        PrivateTmp = true;

        # No path from "code exec as qbittorrent" to "root": no suid/sgid
        # execution, no capabilities, no gaining privileges post-exec.
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";

        # Kernel attack-surface reduction.
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        PrivateDevices = true;
        # /proc hygiene: hide other processes' entries (invisible = can
        # only see its own), and mount /proc with only PID directories —
        # no /proc/meminfo, /proc/cpuinfo, /proc/net etc. First suspect
        # if the service ever fails post-update with ENOENT on /proc/*.
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictNamespaces = true;  # blocks the *process* creating new
                                    # namespaces; joining /run/netns/vpn is
                                    # done by systemd before exec, unaffected
        LockPersonality = true;
        RestrictRealtime = true;
        MemoryDenyWriteExecute = true;  # no W|X memory; qbittorrent-nox has
                                        # no JIT — first suspect if it ever
                                        # crashes on start after an update
        RestrictAddressFamilies = [
          "AF_INET" "AF_INET6"
          "AF_UNIX"     # journal logging
          "AF_NETLINK"  # libtorrent enumerates interfaces/routes via netlink
        ];
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];

        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=8080 --confirm-legal-notice";
      };
    };
  };
}