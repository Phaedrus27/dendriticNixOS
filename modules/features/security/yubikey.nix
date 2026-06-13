{ self, inputs, ... }: {
  flake.nixosModules.yubikey = { pkgs, lib, ... }: {

    # ── FIDO2: interactive auth (SSH sk-keys, sudo, LUKS) ───────────────
    # enable=true is REQUIRED for any pam_u2f line to be emitted. (enable=false
    # + per-service u2fAuth=true emits NOTHING — verified the hard way.)
    # enable defaults u2fAuth ON for every PAM service, so we opt OUT of the
    # unlock path; sudo keeps the default-on grant → touch-to-sudo, no password.
    security.pam.u2f = {
      enable = true;
      control = "sufficient";
      settings = {
        cue = true;
        # Fixed origin: one enrollment works on every host, current and
        # future. (Default pam://$HOSTNAME is why the old authfiles
        # diverged per machine.)
        origin = "pam://phaedrus";
        appid = "pam://phaedrus";
        authfile = pkgs.writeText "u2f_mappings" ''
          phaedrus:rELX0wy5c6jLTTZn/br44PmmRzA9AQG6ETdujfbO3xg5V1tWy0fGpc6m8Epm9XWkfqfomoPkPjauhpITqTh/ww==,s480h3rliey9z8XxMGs70OzPMken8ffJ/W3YHk2guD02xkeBh8IqWFjJ+m5+vJa5SzbvM0YemdULdiGcOA758Q==,es256,+presence:0w2JUMOrqsgTCJ68durzPfR5XEK82t/s2HUukJXBvMXYSaOXC2bzAlQca4I3dcORSx6qUIt7u8wapNrjTrsJmw==,FVozS59qYUHX6t7OHPT9yQQR5TlqwtDmiIPcLRfj0m74+sskH/r5ICtUbU0BRhDZxYXsX71hCcxa0TTgdwJptw==,es256,+presence
        '';
      };
    };

    # Opt OUT of the unlock path — the screen lock / login defend physical
    # presence, which a touch doesn't help (an attacker at the machine can
    # touch the key too). Also the wake-from-sleep delay fix.
    # NOTE: if noctalia's locker authenticates against a service other than
    # these, add its name here — confirm post-rebuild with grep -l u2f /etc/pam.d/*
    security.pam.services.login.u2fAuth = false;
    security.pam.services.greetd.u2fAuth = false;
    security.pam.services.su.u2fAuth = false;      # add
    security.pam.services.sshd.u2fAuth = false;    # add
    # sudo keeps the default-on grant from enable=true (no explicit line needed).

    # sk-key stubs use non-default filenames, so tell ssh to offer them.
    programs.ssh.extraConfig = ''
      IdentityFile ~/.ssh/id_yubikeyA
      IdentityFile ~/.ssh/id_yubikeyC
    '';

    # ── PIV: sops secret editing only ────────────────────────────────────
    services.pcscd.enable = true;

    environment.systemPackages = with pkgs; [
      yubikey-manager
      age
      age-plugin-yubikey
      sops
    ];

    services.udev.packages = [ pkgs.yubikey-personalization ];
  };
}