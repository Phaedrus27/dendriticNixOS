{ self, ... }: {
  flake.nixosModules.mewSops = { pkgs, ... }: {
    sops = {
      defaultSopsFile = "${self}/secrets/secrets.yaml";
      age.plugins = [ pkgs.age-plugin-yubikey ];
      secrets.tailscale_authkey = {};
      secrets.u2f_mappings = {
        path = "/etc/u2f_mappings";
        mode = "0444";
      };
    };
  };
}