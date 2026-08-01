{ self, inputs, ... }: {
  flake.nixosModules.base = { lib, ... }: {
    # ┌─────────────────────────────────────────────────────────────┐
    # │ base — imported by every host in the fleet                  │
    # │  firmware/zram, timezone   universal hardware + locale      │
    # │  nix                       flakes, GC, store-size guards    │
    # │  boot                      ESP generation cap, /tmp hygiene │
    # │  logging                   journald cap                     │
    # │  ssh                       policy only; hosts opt in        │
    # └─────────────────────────────────────────────────────────────┘

    imports = [
      self.nixosModules.tailscale
    ];

    # ──── Firmware & memory ────
    services.fwupd.enable = true;
    zramSwap.enable = true;

    time.timeZone = lib.mkDefault "Europe/Brussels";

    # ──── Nix itself ────
    # Declared system-wide so fresh installs work day one,
    # instead of riding an imperative ~/.config/nix/nix.conf.
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Root-equivalent by design: a trusted user can set substituters and
    # import arbitrary store paths through the daemon. Acceptable on a
    # single-admin fleet; revisit if any host ever gains a second operator.
    nix.settings.trusted-users = [ "root" "phaedrus" ];

    # Scheduled GC alone cannot prevent ENOSPC: during a rebuild-heavy week
    # every generation sits inside the retention window, so the weekly run
    # finds nothing eligible and root fills anyway. These reclaim mid-build
    # instead, turning what would be a wedged filesystem into a GC pause.
    nix.settings.min-free = 5368709120;    # 5 GiB
    nix.settings.max-free = 10737418240;   # 10 GiB

    # Without pinning, `nix shell nixpkgs#...` fetches a second nixpkgs
    # unrelated to the flake input — duplicate store on hosts already
    # short of root space.
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    # Rebuilds share squirtle with transcoding and seeding; nix must yield
    # rather than compete for CPU and disk.
    nix.daemonCPUSchedPolicy = "idle";
    nix.daemonIOSchedClass = "idle";

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    nix.optimise.automatic = true;

    nixpkgs.config.allowUnfree = true;

    # ──── Boot & temp ────
    # Each generation writes a kernel + initrd to a ~512M ESP. Uncapped
    # entries fill it during churny weeks — the same failure as a full
    # root, but it breaks booting rather than writing.
    boot.loader.systemd-boot.configurationLimit = 10;

    # Nothing else clears /tmp, and on most hosts it shares the root
    # partition. Disk-backed rather than tmpfs so large builds can't OOM.
    boot.tmp.cleanOnBoot = true;

    # ──── Logging ────
    # mkDefault so a host with a tighter partition can lower it alone.
    services.journald.extraConfig = lib.mkDefault "SystemMaxUse=500M";

    # ──── SSH policy: hosts opt in with services.openssh.enable ────
    # Settings are inert until the service is enabled; declaring the
    # policy here means SSH can never arrive un-hardened on a new host.
    services.openssh.settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };

    users.users.phaedrus.openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJtarCyjvvCxzi1PwWavZXaPLcHRiDeIAZr2tyAFA+zXAAAADHNzaDp5dWJpa2V5QQ== yubikeyA"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOpNEHSKkHZCiCkuss0aNrLFKet3gEkQbWfysFzpgI+bAAAADHNzaDp5dWJpa2V5Qw== yubikeyC"
    ];
  };
}