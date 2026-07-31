{ ... }: {
  # Central scan service: squirtle is the ONLY SANE host on the fleet.
  # Every other device (workstations, wife's laptop, phones) scans through
  # this web UI — no per-client SANE, no per-client eSCL quirks to fight.
  # Runs as a systemd service, so it reads /etc/sane-config from the unit
  # env, never a login shell (the trap that stalled the workstation attempt).
  flake.nixosModules.scanServer = { pkgs, ... }:
    let
      # Static eSCL endpoint for the Brother, discovery disabled.
      # Proven: standalone airscan against this exact URL returned clean scans
      # while SANE's built-in escl client truncated and appended an HTML error.
      # Pinned (not mDNS) because the unit sleeps and its .local goes unreliable
      # then — same rationale as the IP-pinned print queue.
      airscanConf = pkgs.writeTextFile {
        name = "airscan.conf";
        destination = "/etc/sane.d/airscan.conf";
        text = ''
          [options]
          discovery = disable

          [devices]
          "Brother DCP-L2530DW" = http://192.168.1.140/eSCL, eSCL
        '';
      };
    in {
      # ── SANE backend: airscan only ──────────────────────────────────────
      hardware.sane = {
        # scanservjs flips hardware.sane.enable itself; we only supply backends.
        # airscanConf must come AFTER sane-airscan: mkSaneConfig symlinks configs
        # last-wins, so this shadows the package's discovery-based default conf.
        extraBackends = [ pkgs.sane-airscan airscanConf ];
        # This unit's transfers fail on the built-in escl client — force airscan.
        disabledDefaultBackends = [ "escl" ];
      };

      # ── scanservjs web UI ───────────────────────────────────────────────
      services.scanservjs = {
        enable = true;
        settings = {
          host = "0.0.0.0";   # default 127.0.0.1 is localhost-only; bind all ifaces for LAN + tailnet reach
          port = 8080;
        };
      };

      # ── Firewall ────────────────────────────────────────────────────────
      # Web UI reachable from any device on the LAN/tailnet. Scope to a specific
      # interface via networking.firewall.interfaces.<if> if you'd rather not
      # expose it fleet-wide.
      networking.firewall.allowedTCPPorts = [ 8080 ];
    };
}