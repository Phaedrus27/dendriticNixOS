{ self, inputs, ... }: {
  flake.nixosModules.tailscale = { lib, pkgs, config, ... }: {
    services.tailscale = {
      enable = true;
      # Default to client — hosts that act as subnet routers override this to "server"
      useRoutingFeatures = lib.mkDefault "client";
      # Only set authKeyFile if the secret is declared — allows install without SOPS configured
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