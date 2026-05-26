{ self, inputs, ... }: {
  flake.nixosModules.tailscale = { lib, pkgs, config, ... }: {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = lib.mkDefault "client";
      # authKeyFile only set if the host declares the secret — headless hosts like squirtle
      # use this for unattended auth. Interactive hosts authenticate manually with tailscale up.
      authKeyFile = lib.mkIf (config.sops ? secrets && config.sops.secrets ? tailscale_authkey)
        config.sops.secrets.tailscale_authkey.path;
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    environment.systemPackages = [ pkgs.tailscale ];
  };
}