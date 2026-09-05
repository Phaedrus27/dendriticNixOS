{ self, inputs, ... }: {
  flake.nixosConfigurations.charizard = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.charizardConfiguration ];
  };

  flake.nixosModules.charizardConfiguration = { pkgs, lib, config, ... }: {
    imports = [
      self.nixosModules.charizardHardware
      self.nixosModules.workstation
      self.nixosModules.charizardSecurity
      self.nixosModules.gaming
      self.nixosModules.syncthing
      self.nixosModules.chromium
      self.nixosModules.keychron
      self.nixosModules.niriSession
      self.nixosModules.charizardNiri
      self.nixosModules.base
      self.nixosModules.editingApps
      self.nixosModules.streaming
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking = {
      hostName = "charizard";
      interfaces.enp7s0.ipv4.addresses = [{
        address = "192.168.1.6";
        prefixLength = 24;
      }];
      defaultGateway = "192.168.1.1";
      nameservers = [ "192.168.1.16" ];
    };

    services.tuned.enable = true;
    services.openssh.enable = true;

    system.stateVersion = "25.11";

    # ──── Session selection ────
    # HDR requires gamescope on its own DRM backend: niri exposes no
    # colour-management protocol, so a nested gamescope can't negotiate it, and
    # two compositors can't share DRM master on one VT. The gamescope session
    # must therefore be a peer of niri-session, not a child — which needs a
    # picker at logout.
    #
    # initial_session preserves the existing boot autologin; default_session is
    # only reached on explicit logout. tuigreet authenticates as the greetd PAM
    # service, which yubikey.nix opts out of u2f — so this depends on the
    # account password being set.
    services.greetd.settings = {
      initial_session = {
        command = "niri-session";
        user = "phaedrus";
      };
      default_session = lib.mkForce {
        command = "${lib.getExe pkgs.tuigreet} --remember --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };

    # nixos-raspberrypi's binary cache, registered at the daemon level: flake
    # nixConfig can't add substituters for non-trusted users, and charizard is
    # the fleet's aarch64 image builder (pidgey now; bulbasaur/abra onboarding
    # later). substituters merges with the module default, so cache.nixos.org
    # stays first.
    nix.settings = {
      substituters = [ "https://nixos-raspberrypi.cachix.org" ];
      trusted-public-keys = [
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      ];
    };
  };
}