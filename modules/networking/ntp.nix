{ ... }:
{
  flake.modules.nixos.ntp-server =
    { ... }:
    {
      # Time source for the fleet; clients are pointed here via DHCP.
      services.chrony = {
        enable = true;
        extraConfig = "allow 192.168.1.0/24";
      };

      networking.firewall.interfaces."end0".allowedUDPPorts = [ 123 ];
    };
}