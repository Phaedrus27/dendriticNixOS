{ self, inputs, ... }: {
  flake.nixosModules.workstation = { pkgs, lib, ... }: {

    imports = [
      self.nixosModules.coreApps
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
    services.printing.enable = true;
    services.avahi = {                     # promoted from charizard: resolves .local,
      enable = true;                       # required for the deviceUri below
      nssmdns4 = true;
      openFirewall = true;                 # mDNS needs 5353/UDP both ways
    };

    hardware.printers = {
      ensurePrinters = [{
        name = "Brother_DCP-L2530DW";
        deviceUri = "ipp://192.168.1.140:631/ipp/print";   # IP (UniFi-reserved), not .local — mDNS unreliable, printer sleeps
        model = "everywhere";
        ppdOptions.PageSize = "A4";
      }];
      ensureDefaultPrinter = "Brother_DCP-L2530DW";
    };

    systemd.services.ensure-printers = {
      after = [ "cups.service" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
    
    services.upower.enable = true;

    # ── Primary user ────────────────────────────────────────────────────
    users.users.phaedrus = {
      isNormalUser = true;
      description = "phaedrus";
      extraGroups = [ "networkmanager" "wheel" "bluetooth" ];
    };

    # ── Common desktop packages ─────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      pywalfox-native
      proton-vpn                         # moved from environment.nix
      tailscale-systray                  # moved from environment.nix
    ];
  };
}