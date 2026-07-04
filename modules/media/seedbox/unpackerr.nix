{ self, inputs, ... }: {
  flake.nixosModules.unpackerr = { config, pkgs, ... }: {

    sops.secrets.sonarr_api_key = { owner = "unpackerr"; };
    sops.secrets.radarr_api_key = { owner = "unpackerr"; };

    users.users.unpackerr = {
      isSystemUser = true;
      group = "media";
    };

    systemd.services.unpackerr = {
      description = "Unpackerr - Extract downloads for Sonarr and Radarr";
      after = [ "network.target" "sonarr.service" "radarr.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        UN_SONARR_0_URL = "http://localhost:8989";
        UN_SONARR_0_PATHS_0 = "/mnt/storage/downloads";
        UN_SONARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
        UN_RADARR_0_URL = "http://localhost:7878";
        UN_RADARR_0_PATHS_0 = "/mnt/storage/downloads";
        UN_RADARR_0_PROTOCOLS = "torrent,TorrentDownloadProtocol";
      };
      serviceConfig = {
        Type = "simple";
        User = "unpackerr";
        Group = "media";
        Restart = "on-failure";

        # Sandboxing: unpackerr feeds attacker-chosen archives to unrar,
        # the classic path-traversal/RCE surface (CVE-2022-30333 class).
        # The write scope below is what caps a traversal exploit's blast
        # radius: escapes resolve against a read-only filesystem.

        # Filesystem: OS read-only; only the completed-downloads tree is
        # writable (extractions happen in place next to the archive).
        # Incomplete tree on cache is deliberately absent — unpackerr
        # must never touch partial downloads.
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/mnt/storage/downloads" ];
        PrivateTmp = true;

        # No privilege-escalation path.
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
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;

        # Go binary; no JIT, MDWE is safe. First suspect on a
        # crash-at-start after an unpackerr update.
        MemoryDenyWriteExecute = true;

        RestrictAddressFamilies = [
          "AF_INET"   # localhost APIs to sonarr/radarr
          "AF_INET6"  # localhost may resolve to ::1 first
          "AF_UNIX"   # journal logging
        ];
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];

        ExecStart = pkgs.writeShellScript "unpackerr-start" ''
          export UN_SONARR_0_API_KEY=$(cat ${config.sops.secrets.sonarr_api_key.path})
          export UN_RADARR_0_API_KEY=$(cat ${config.sops.secrets.radarr_api_key.path})
          exec ${pkgs.unpackerr}/bin/unpackerr
        '';
      };
    };

  };
}