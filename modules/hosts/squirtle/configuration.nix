{ self, inputs, ... }: {

  flake.nixosModules.squirtleConfiguration = { pkgs, lib, ... }: {
    imports = [
    self.nixosModules.squirtleHardware
    self.nixosModules.squirtleStorage
    self.nixosModules.tailscale
    self.nixosModules.sops
    self.nixosModules.squirtleSops
    self.nixosModules.samba
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.phaedrus = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "changeme";
    openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKsZFvX8+9AFnY4tuLj7izlgccAfggs5ZzOLx9gpeDvh phaedrus@charizard"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCgFjsQVJFCrBQwiRcre1n7nkzMXcB7MnyQk7QdW32/wfoDeP071EyQ9aDnndtRs9XVvvvuGYwSjOePudH21HTofbkQ4ojC80UyLizfL+uZLF4pmSkRdoYIZs9XI+UhZQ6282259sJb62D4tP0HZDJTfrhMZnHQw2gqHRyP1Iqcrg/iN28vKp9xUP4B7pEq4PRdxEcxM3NMH3cUZQJiI0ez6EPx9LRzWcWyuaXfMDZZshe3ZTOydn1WGNhvpa1VEfO6Zg9XrqFd2bgAUFVD4eRucdq10yzS7EVRrw13CqW+2SlNnSGp+aaHElzrGYEE8wf4TcxaVHJ2dWSdoU6wy8YN cardno:29_526_888"
  ];
  };

   networking = {
      hostName = "squirtle";
      interfaces.enp3s0.ipv4.addresses = [{
        address = "192.168.1.7";
        prefixLength = 24;
      }];
      defaultGateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
      networkmanager.enable = true;
      firewall.enable = true;
    };

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    environment.systemPackages = with pkgs; [
      git
      htop
      wget
      curl
      smartmontools
      lsof
      ncdu
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    nixpkgs.config.allowUnfree = true;

    security.sudo.wheelNeedsPassword = false;

    system.stateVersion = "25.11";
  };
}