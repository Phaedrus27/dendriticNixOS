{ self, inputs, ... }: {
  flake.nixosModules.tailscale = { lib, pkgs, config, ... }: {

    options.dendriticNixOS.tailscale.authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to Tailscale auth key file. If null, authenticate manually with tailscale up.";
    };

    config = {
      services.tailscale = {
        enable = true;
        useRoutingFeatures = lib.mkDefault "client";
        authKeyFile = lib.mkIf 
          (config.dendriticNixOS.tailscale.authKeyFile != null)
          config.dendriticNixOS.tailscale.authKeyFile;
      };

      networking.firewall = {
        trustedInterfaces = [ "tailscale0" ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      environment.systemPackages = [ pkgs.tailscale ];
    };
  };
}