{ self, inputs, ... }: {
  flake.nixosModules.sops = { pkgs, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Fleet-wide secret decryption. Any host importing `sops` derives its age
    # identity from its own SSH ed25519 host key, so a secret encrypted to that
    # host's age recipient unlocks here with no extra key material on disk.
    sops = {
      defaultSopsFile = "${self}/modules/secrets/secrets.yaml";
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    environment.systemPackages = [ pkgs.sops pkgs.age ];
  };
}