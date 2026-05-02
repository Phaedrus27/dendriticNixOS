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