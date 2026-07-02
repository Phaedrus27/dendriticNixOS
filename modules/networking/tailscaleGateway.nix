{ ... }:
{
  flake.nixosModules.tailscaleGateway =
    { ... }:
    {
      # Route LAN traffic for tailnet peers and act as exit node.
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

      services.tailscale = {
        useRoutingFeatures = "server";
        # Advertises the current flat LAN; becomes 192.168.10.0/24 (plus any
        # other reachable VLANs) at cutover. Routes and exit node need approval
        # in the admin console after the first connection. Reapplied via
        # `tailscale set` on every activation.
        extraSetFlags = [
          "--advertise-routes=192.168.1.0/24"
          "--advertise-exit-node"
        ];
      };
    };
}