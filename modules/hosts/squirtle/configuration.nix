{ self, inputs, ... }: {

  flake.nixosModules.squirtleConfiguration = { pkgs, lib, ... }: {
    imports = [
    self.nixosModules.squirtleHardware
    self.nixosModules.squirtleStorage
    self.nixosModules.tailscale
    self.nixosModules.sops
    self.nixosModules.squirtleSops
    self.nixosModules.samba
    self.nixosModules.mediaServer
    self.nixosModules.syncthing
    self.nixosModules.paperless
    self.nixosModules.backup
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.phaedrus = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "changeme";
    openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDAql98j2hnVZLCE2DSNDaaZJB08Zr27IsT96YCmGIf0kBeWjmWDd/jkx8/+9wE6gwhZpdZL1oMUcuxwoNvxx1/rv5JZA1aWObt1dfme5/IKfMWdWwI+2pBLvWoPA+H5b4GbTemQTFeD2gd/ykNELBsnd8jGi64JKF8bblARriIB+v/Swy9sMkmWiS7eggQAI7BZ+D/Ms+BO6nJIR/qjUBnvgejNsDHxb7nfj/5fBCGOPEzJT68BEYfw5U3V7caYe++mF0L2LvrsBQohSGwZSad31Vg9PAMyMDk0GfuGoEPVGglo/YDUCCgvfqPIom7GqyPqx023dHEGJosSvO8fY7H cardno:29_526_888"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTq80xXZrMiX091qfxSttC+4UjcR2P7mbyHqbHGsMBfdRQ01unMDD2Nobg6gJ0+14/67js0EQxeqxrnCRHsfi94kMlYZKI9IExfHRTvObAG1+odllqM8G3LmHiKSOpecQDCi+2MgPD1GSElXVxKKOj1febtv/3dZEdSVGyugI0Uxvq7GsU8GUJM/lDaq6+lI8YbYeiVR27eSNgx1T9Etcv9hXEoKS0wECm23DXo+uEEDaQhAln5GS1ypr0bf5FFkauxAVuzygYd7sPqFTG4oE8quj964y/QT+kS4LUHcE6zwRqI0AgoPBGxwUiZAU6r3uhUNoa0hOV2v5futVmiQyD cardno:31_858_399"
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