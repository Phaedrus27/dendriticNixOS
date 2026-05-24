{ self, inputs, ... }: {
  flake.nixosModules.tailscale = { lib, pkgs, config, ... }: {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      authKeyFile = config.sops.secrets.tailscale_authkey.path;
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    environment.systemPackages = [ pkgs.tailscale ];
  };
}