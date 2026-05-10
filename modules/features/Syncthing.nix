{ self, inputs, ... }: {
  flake.nixosModules.syncthing = { lib, config, ... }: {
    services.syncthing = {
      enable = true;
      user = "phaedrus";
      dataDir = "/home/phaedrus";
      configDir = "/home/phaedrus/.config/syncthing";
    };

    networking.firewall.allowedTCPPorts = [ 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 21027 ];
  };
}