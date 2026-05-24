{ self, ... }: {
  flake.nixosModules.mewSops = { pkgs, ... }: {
    sops = {
      defaultSopsFile = "${self}/secrets/secrets.yaml";
      age.plugins = [ pkgs.age-plugin-yubikey ];
      secrets.tailscale_authkey = {};
    };
  };
}