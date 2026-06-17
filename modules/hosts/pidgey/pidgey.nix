# pidgey — network infrastructure host
#
# Aspects:
#   base               sops host key, fleet sshKeys, monitoring, tailscale base
#   pidgey-hardware    Pi 5 + USB SSD boot
#   pidgey-dns         Pi-hole — adblock + region-TLD (.kanto/.johto/…) resolution
#   tailscale-gateway  subnet router + exit node + split-DNS target
#   tang-server        LAN-only LUKS key server
#   ntp-server         chrony time server for the fleet
{ config, ... }:
{
  flake.modules.nixos.pidgey = {
    imports = [
      config.flake.modules.nixos.base
      config.flake.modules.nixos.pidgey-hardware
      config.flake.modules.nixos.pidgey-dns
      config.flake.modules.nixos.tailscale-gateway
      config.flake.modules.nixos.tang-server
      config.flake.modules.nixos.ntp-server
    ];

    networking.hostName = "pidgey";

    # No data-bearing services run here, so there is no restic target; the only
    # durable state is this configuration, tracked in git.
    system.stateVersion = "25.11";
  };
}