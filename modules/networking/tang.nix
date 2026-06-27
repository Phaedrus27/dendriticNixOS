{ ... }:
{
  flake.modules.nixos.tang =
    { ... }:
    {
      # LUKS unlock key server for squirtle/bulbasaur/charizard. Binds the LAN
      # IP and accepts only LAN clients, so bound disks cannot unlock off the
      # home network. Verify listenStream/ipAddressAllow against the channel's
      # tang module — the socket-activation attrs have shifted across versions.
      services.tang = {
        enable = true;
        listenStream = [ "192.168.1.5:7654" ];
        ipAddressAllow = [ "192.168.1.0/24" ];
      };

      networking.firewall.interfaces."end0".allowedTCPPorts = [ 7654 ];
    };
}