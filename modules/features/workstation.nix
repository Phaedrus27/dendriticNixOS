{ self, inputs, ... }: {
  flake.nixosModules.workstation = { pkgs, lib, ... }: {

    imports = [
      self.nixosModules.firefox          # moved: a browser isn't a session concern
    ];

    # ── Networking ──────────────────────────────────────────────────────
    # moved from environment.nix: both desktops want NM under any DE,
    # and GNOME expects it.
    networking.networkmanager.enable = true;

    # ── Locale & input ──────────────────────────────────────────────────
    time.timeZone = lib.mkDefault "Europe/Brussels";
    i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";
    services.xserver.xkb = {
      layout = lib.mkDefault "fr";
      variant = lib.mkDefault "afnor";
    };
    console.keyMap = lib.mkDefault "fr";
    services.libinput.enable = true;

    # ── Git: identity in /etc/gitconfig, fleet-wide ─────────────────────
    programs.git = {
      enable = true;
      config = {
        user.name = "Phaedrus27";
        user.email = "Phaedrus27@proton.me";
        init.defaultBranch = "main";
      };
    };

    # ── Audio: PipeWire ─────────────────────────────────────────────────
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # ── Printing & power ────────────────────────────────────────────────
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint hplip brlaser epson-escpr samsung-unified-linux-driver
      ];
    };
    services.upower.enable = true;

    # ── Primary user ────────────────────────────────────────────────────
    users.users.phaedrus = {
      isNormalUser = true;
      description = "phaedrus";
      extraGroups = [ "networkmanager" "wheel" ];
    };

    # ── Common desktop packages ─────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      vscodium
      vesktop
      vlc
      pywalfox-native
      proton-vpn                         # moved from environment.nix
      tailscale-systray                  # moved from environment.nix
    ];
  };
}