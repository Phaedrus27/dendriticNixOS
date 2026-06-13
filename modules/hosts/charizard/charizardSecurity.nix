{ self, ... }: {
  flake.nixosModules.charizardSecurity = { pkgs, ... }: {
    imports = [ self.nixosModules.yubikey ];

    # Squirtle backup job SSHes into charizard using this key
    users.users.phaedrus.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICy71fHrSglydDTpHaoPGmwAqQNn9Z3DbMWQ2B41gWDn squirtle-backup"
    ];
  };
}