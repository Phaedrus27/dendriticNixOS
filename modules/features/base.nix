{ self, ... }: {
  flake.nixosModules.base = { pkgs, config, lib, ... }: {
    imports = [ 
      self.nixosModules.tailscale 
      ];

    # ── Firmware & memory ─────────────────────────────────────────────
    services.fwupd.enable = true;
    zramSwap.enable = true;

    time.timeZone = lib.mkDefault "Europe/Brussels";

    # ── Nix itself ────────────────────────────────────────────────────
    # Declared system-wide so fresh installs work day one,
    # instead of riding an imperative ~/.config/nix/nix.conf.
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    nix.optimise.automatic = true;

    # Scheduled GC can't help during a heavy rebuild week: every generation
    # is inside the retention window, so the weekly run finds nothing
    # eligible. This reclaims mid-build instead — a rebuild that would
    # otherwise hit ENOSPC degrades into a GC pause.
    nix.settings.min-free = 5368709120;    # 5 GiB
    nix.settings.max-free = 10737418240;   # 10 GiB

    nixpkgs.config.allowUnfree = true;

    # ── Logging ───────────────────────────────────────────────────────
    services.journald.extraConfig = "SystemMaxUse=500M";

    # ── SSH policy: hosts opt in with services.openssh.enable ─────────
    # Settings are inert until the service is enabled; declaring the
    # policy here means SSH can never arrive un-hardened on a new host.
    services.openssh.settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };

    nix.settings.trusted-users = ["root" "phaedrus" ];

    users.users.phaedrus.openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJtarCyjvvCxzi1PwWavZXaPLcHRiDeIAZr2tyAFA+zXAAAADHNzaDp5dWJpa2V5QQ== yubikeyA"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOpNEHSKkHZCiCkuss0aNrLFKet3gEkQbWfysFzpgI+bAAAADHNzaDp5dWJpa2V5Qw== yubikeyC"
    ];
  };
}