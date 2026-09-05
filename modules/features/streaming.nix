{ self, inputs, ... }: {
  # ┌─────────────────────────────────────────────────────────────┐
  # │ streaming — Sunshine host for Moonlight clients             │
  # │  Separated from gaming.nix deliberately: this grants        │
  # │  CAP_SYS_ADMIN and uinput, so its blast radius is a         │
  # │  security question, not a gaming one.                       │
  # └─────────────────────────────────────────────────────────────┘
  flake.nixosModules.streaming = { pkgs, ... }: {

    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
      settings.sunshine_name = "charizard";
      applications.apps = [
        {
          name = "Steam Big Picture";
          # capSysAdmin runs these as root; drop back to phaedrus to reach the
          # real Wayland session and the user's Steam.
          detached = [ "setsid sudo -u phaedrus steam steam://open/bigpicture" ];
          "prep-cmd" = [
            { do = ""; undo = "sudo -u phaedrus setsid steam steam://close/bigpicture"; }
          ];
          "image-path" = "steam.png";
        }
      ];
    };

    # Virtual input for Moonlight clients (group + udev perms + module). Without
    # group membership you get video but no remote keyboard/mouse.
    hardware.uinput.enable = true;

    users.users.phaedrus.extraGroups = [ "uinput" ];
  };
}