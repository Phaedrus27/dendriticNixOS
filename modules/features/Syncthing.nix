{ self, inputs, ... }: {
  flake.nixosModules.syncthing = { lib, config, ... }: {

    services.syncthing = {
      enable = true;
      user = "phaedrus";
      dataDir = "/home/phaedrus";
      configDir = "/home/phaedrus/.config/syncthing";

      folders = {
        "obsidian" = {
          path = lib.mkMerge [
            (lib.mkIf (config.networking.hostName == "squirtle") "/mnt/storage/obsidian")
            (lib.mkIf (config.networking.hostName == "charizard") "/home/phaedrus/obsidian")
            (lib.mkIf (config.networking.hostName == "mew") "/home/phaedrus/obsidian")
          ];
          devices = lib.mkMerge [
            (lib.mkIf (config.networking.hostName == "squirtle") [ "charizard" "mew" ])
            (lib.mkIf (config.networking.hostName == "charizard") [ "squirtle" "mew" ])
            (lib.mkIf (config.networking.hostName == "mew") [ "squirtle" "charizard" ])
          ];
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 21027 ];
  };
}