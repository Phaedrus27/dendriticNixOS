{ self, inputs, ... }: {
  flake.nixosModules.squirtleSops = { ... }: {
    sops = {
      defaultSopsFile = "${self}/secrets/squirtle/secrets.yaml";
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets.tailscale_authkey = {};
      secrets.protonvpn_privkey = {};
      secrets.protonvpn_pubkey = {};
      secrets.protonvpn_endpoint = {};
      secrets.protonvpn_address = {};
      secrets.discord_webhook = {};
      secrets.paperless_admin_password = {
        owner = "paperless";
      };
      secrets.restic_password = {};
    };
  };
}