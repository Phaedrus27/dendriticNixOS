{ self, inputs, ... }: {
  flake.nixosModules.tailscale = { lib, pkgs, config, ... }: {

    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      authKeyFile = lib.mkIf (config.sops.secrets ? tailscale_authkey) 
        config.sops.secrets.tailscale_authkey.path;
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    environment.systemPackages = [ pkgs.tailscale ];
  };
}