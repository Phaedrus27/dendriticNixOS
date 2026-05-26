{ self, inputs, ... }: {
  flake.nixosModules.syncthing = { lib, config, ... }: {
    services.syncthing = {
      enable = true;
      user = "phaedrus";
      dataDir = "/home/phaedrus";
      configDir = "/home/phaedrus/.config/syncthing";

      settings = {
        devices = {
          squirtle = { 
            id = "CCRSGFK-2ELXY6V-WCLW6LK-3KAWTEO-PVUOMMF-BPDMJZ7-ZTKP2RJ-WNXAZQG";
            addresses = [ "tcp://100.85.58.101:22000" ];
          };
          charizard = { 
            id = "H47BPGN-DLHB5DZ-HHHFXRF-RQXMFLY-UZTEPJ5-XQPRUVU-JW22HW7-RRCKXQH";
            addresses = [ "tcp://100.117.81.78:22000" ];
          };
          mew = { 
            id = "BA6TEFV-CZCEQYZ-HIPS6W3-BFB53FN-B2MBT2K-LAVPEW4-4CISR2V-IXLCUQA";
            addresses = [ "tcp://100.122.227.20:22000" ];
          };
          phone = { 
            id = "ND3MRVS-YYZLSRP-CDNPNQU-YGE2UN4-HGQQEVR-SQY35VL-LL445N3-A6KJ6QQ";
            addresses = [ "tcp://100.91.247.8:22000" ];
          };
        };

        folders = {
          syncthing = {
            path = lib.mkMerge [
              (lib.mkIf (config.networking.hostName == "squirtle") "/mnt/cache/syncthing")
              (lib.mkIf (config.networking.hostName == "charizard") "/home/phaedrus/syncthing")
              (lib.mkIf (config.networking.hostName == "mew") "/home/phaedrus/syncthing")
            ];
            devices = lib.mkMerge [
              (lib.mkIf (config.networking.hostName == "squirtle") [ "charizard" "mew" "phone" ])
              (lib.mkIf (config.networking.hostName == "charizard") [ "squirtle" ])
              (lib.mkIf (config.networking.hostName == "mew") [ "squirtle" ])
            ];
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 21027 ];
  };
}