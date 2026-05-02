{ self, inputs, ... }: {
  flake.nixosModules.tailscale = { lib, pkgs, config, ... }: {

    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    environment.systemPackages = [ pkgs.tailscale ];
  };
}