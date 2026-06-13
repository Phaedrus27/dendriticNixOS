{ self, inputs, ... }: {
  flake.nixosModules.yubikey = { pkgs, lib, ... }: {

    # ── FIDO2: interactive auth (SSH sk-keys, sudo, LUKS) ───────────────
    # Allowlist shape: enable=false kills the default-on-everywhere
    # behavior (23 PAM services!); u2f is then granted only where it
    # defends a privilege boundary.
    security.pam.u2f = {
      enable = false;
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
    security.pam.services.sudo.u2fAuth = true;
    # security.pam.services.polkit-1.u2fAuth = true;  # optional: GUI auth prompts

    # sk-key stubs use non-default filenames, so tell ssh to offer them
    programs.ssh.extraConfig = ''
      IdentityFile ~/.ssh/id_yubikeyA
      IdentityFile ~/.ssh/id_yubikeyC
    '';

    # ── TRANSITIONAL: OpenPGP SSH path, kept alive during the cutover ────
    # The old auth route (gpg-agent → cardno: RSA keys). Deleted in
    # commit 2, once both sk-keys are verified against every host.
    # NOTE: the SSH_AUTH_SOCK overrides and PKCS11 config remain in
    # charizardSecurity.nix / mewSecurity.nix untouched until commit 2.
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-gtk2;
    };

    # ── PIV: sops secret editing only ────────────────────────────────────
    services.pcscd.enable = true;

    environment.systemPackages = with pkgs; [
      yubikey-manager
      age
      age-plugin-yubikey
      sops
      gnupg          # TRANSITIONAL: leaves with the gpg block in commit 2
    ];

    services.udev.packages = [ pkgs.yubikey-personalization ];
  };
}