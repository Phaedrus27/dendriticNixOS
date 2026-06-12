{ self, inputs, ... }: {
  flake.nixosModules.squirtleSops = { ... }: {
    sops = {
      defaultSopsFile = "${self}/secrets/secrets.yaml";
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
}