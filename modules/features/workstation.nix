{ self, inputs, ... }: {
  flake.nixosModules.workstation = { pkgs, lib, ... }: {

    imports = [
      self.nixosModules.coreApps
    ];

    # ── Networking ──────────────────────────────────────────────────────
    # moved from environment.nix: both desktops want NM under any DE,
    # and GNOME expects it.
    networking.networkmanager.enable = true;

    # systemd-resolved: the layer Tailscale installs split-DNS into on Linux.
    # Without it, roaming machines resolve .home via whatever DHCP offers and
    # never see the tailnet's DNS config. Workstation-scoped: NOT in the
    # tailscale base module, because resolved's stub listener would contend
    # for port 53 with Pi-hole on pidgey.
    services.resolved.enable = true;

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
      services.printing.enable = true;

      services.avahi = {
        enable = true;          # resolves .local for discovery; deviceUri below is IP-based
        nssmdns4 = true;
        openFirewall = true;    # mDNS needs 5353/UDP both ways
      };

      hardware.printers = {
        ensurePrinters = [{
          name = "Brother_DCP-L2530DW";
          deviceUri = "ipp://192.168.1.140:631/ipp/print";   # UniFi-reserved IP — .local unreliable, printer sleeps
          model = "everywhere";
          ppdOptions.PageSize = "A4";
        }];
        ensureDefaultPrinter = "Brother_DCP-L2530DW";
      };

      # ensure-printers calls lpadmin on every activation, which makes CUPS fetch the
      # printer's IPP capabilities. A sleeping printer fails that fetch (exit 1) and
      # fails the whole switch (exit-4). Treat exit 1 as success: registration only
      # needs one successful fetch (persisted in /var/lib/cups), and the printer is
      # usually asleep at rebuild time here.
      # `after` (not `requires`) orders behind CUPS: ensure-printers cycles
      # cups.service itself, and `requires` would send TERM when it stops.
      systemd.services.ensure-printers = {
        after = [ "cups.service" ];
        serviceConfig.SuccessExitStatus = [ 0 1 ];
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
      pywalfox-native
      proton-vpn                         # moved from environment.nix
      tailscale-systray                  # moved from environment.nix
    ];
  };
}