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

        # "client" (accept subnet routes) unless a host overrides — pidgey's
        # gateway module sets "server". NOTE: useRoutingFeatures only applies
        # --accept-routes through the autoconnect path, which requires
        # authKeyFile; this fleet authenticates manually, so the flag is
        # applied via extraSetFlags below instead.
        useRoutingFeatures = lib.mkDefault "client";

        # Accepting pidgey's 192.168.1.0/24 route is what makes the kanto-IP
        # service records reachable off-LAN; without it, roaming clients
        # resolve jellyfin.home to a LAN address they cannot route to.
        # Applied via `tailscale set` on every activation, independent of how
        # the node authenticated. Scoped to client/both so gateway hosts
        # don't accept-routes themselves; merges (list concat) with any
        # extraSetFlags a host module adds, e.g. pidgey's route advertisement.
        extraSetFlags = lib.optional
          (lib.elem config.services.tailscale.useRoutingFeatures [ "client" "both" ])
          "--accept-routes";

        authKeyFile = lib.mkIf
          (config.dendriticNixOS.tailscale.authKeyFile != null)
          config.dendriticNixOS.tailscale.authKeyFile;
      };

      systemd.services.tailscaled = {
        after = lib.mkForce [ "network.target" ];
        wants = lib.mkForce [ "network.target" ];
      };

      networking.firewall = {
        trustedInterfaces = [ "tailscale0" ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      environment.systemPackages = [ pkgs.tailscale ];
    };
  };
}