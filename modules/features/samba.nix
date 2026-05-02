{ self, inputs, ... }: {
  flake.nixosModules.samba = { pkgs, ... }: {

    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "squirtle";
          "security" = "user";
          "guest ok" = "no";
        };
        storage = {
          "path" = "/mnt/storage";
          "browseable" = "yes";
          "read only" = "no";
          "valid users" = "phaedrus";
        };
      };
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}