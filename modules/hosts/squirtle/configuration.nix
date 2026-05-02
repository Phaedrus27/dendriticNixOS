{ self, inputs, ... }: {

  flake.nixosModules.squirtleConfiguration = { pkgs, lib, ... }: {
    imports = [
    self.nixosModules.squirtleHardware
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "squirtle";
  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  users.users.phaedrus = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "changeme";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "25.11";
};
}