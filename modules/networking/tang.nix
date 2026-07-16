{ ... }:
{
  flake.nixosModules.tang =
    { ... }:
    {
      # ──── Tang: LUKS unlock key server ────
      # Network-bound disk encryption for charizard (and future Tang-bound
      # hosts). Binds the LAN IP and accepts only LAN clients, so bound
      # disks cannot unlock off the home network. Never exposed on
      # tailscale0 — remote reachability of pidgey must never mean remote
      # reachability of Tang.
      # Verify listenStream/ipAddressAllow against the channel's tang
      # module — the socket-activation attrs have shifted across versions.
      services.tang = {
        enable = true;
        listenStream = [ "192.168.1.16:7654" ];
        ipAddressAllow = [ "192.168.1.0/24" ];
      };

      # WHY: tang binds the LAN IP specifically; without FreeBind the
      # socket races DHCP at boot — if it starts before the address is
      # assigned, the bind fails permanently and every Tang client hangs
      # at LUKS on its next reboot. Observed 2026-07-02: failed silently
      # at an ordinary boot, undetected for 13 days until charizard
      # rebooted. Verify after rebuild: systemctl show tangd.socket
      # -p FreeBind → FreeBind=yes.
      systemd.sockets.tangd.socketConfig.FreeBind = true;

      networking.firewall.interfaces."end0".allowedTCPPorts = [ 7654 ];
    };
}