{ self, inputs, ... }: {
  flake.nixosModules.yubikey = { pkgs, lib, ... }: {

    # ── FIDO2: interactive auth (SSH sk-keys, sudo, LUKS) ───────────────
    # enable = true is required for pam_u2f to emit anything; enable = false with
    # per-service u2fAuth = true emits nothing. With enable on, u2fAuth defaults
    # ON for every PAM service, so the unlock path is opted out below while sudo
    # keeps the default grant → touch-to-sudo, no password.
    security.pam.u2f = {
      enable = true;
      control = "sufficient";
      settings = {
        cue = true;
        # Fixed origin instead of the default pam://$HOSTNAME, so one enrollment
        # is valid on every host rather than tied to a single machine.
        origin = "pam://phaedrus";
        appid = "pam://phaedrus";
        authfile = pkgs.writeText "u2f_mappings" ''
          phaedrus:rELX0wy5c6jLTTZn/br44PmmRzA9AQG6ETdujfbO3xg5V1tWy0fGpc6m8Epm9XWkfqfomoPkPjauhpITqTh/ww==,s480h3rliey9z8XxMGs70OzPMken8ffJ/W3YHk2guD02xkeBh8IqWFjJ+m5+vJa5SzbvM0YemdULdiGcOA758Q==,es256,+presence:0w2JUMOrqsgTCJ68durzPfR5XEK82t/s2HUukJXBvMXYSaOXC2bzAlQca4I3dcORSx6qUIt7u8wapNrjTrsJmw==,FVozS59qYUHX6t7OHPT9yQQR5TlqwtDmiIPcLRfj0m74+sskH/r5ICtUbU0BRhDZxYXsX71hCcxa0TTgdwJptw==,es256,+presence
        '';
      };
    };

    # Opt out of u2f on these services: at the physical machine a touch adds no
    # security (anyone present can touch the key) and it avoids a wake-from-sleep
    # delay. The locker (noctalia) authenticates against one of these; a locker
    # on a different PAM service would also need opting out here.
    security.pam.services.login.u2fAuth = false;
    security.pam.services.greetd.u2fAuth = false;
    security.pam.services.su.u2fAuth = false;
    security.pam.services.sshd.u2fAuth = false;
    # sudo is not listed: it keeps the default-on grant, giving touch-to-sudo.

    # sk-key files use non-default names, so ssh is told to offer them.
    programs.ssh.extraConfig = ''
      IdentityFile ~/.ssh/id_yubikeyA
      IdentityFile ~/.ssh/id_yubikeyC
    '';

    # ── PIV: sops secret editing only ────────────────────────────────────
    services.pcscd.enable = true;

    # age identity file, managed here so every workstation carries both keys and
    # stays consistent. The AGE-PLUGIN-YUBIKEY-1 strings are not secret — they are
    # slot pointers; decryption still requires the physical key + PIN + touch, the
    # same trust level as the recipient pubkeys in .sops.yaml.
    environment.etc."sops/age/keys.txt".text = ''
      # yubikeyA — serial 31858399
      AGE-PLUGIN-YUBIKEY-1MU0WVQVZL0L52YQPHZP2N
      # yubikeyC — serial 29526888
      AGE-PLUGIN-YUBIKEY-1DZ9UYQVZH527VUSA53X7X
    '';

    # sops CLI reads identities from here rather than ~/.config/sops/age.
    environment.variables.SOPS_AGE_KEY_FILE = "/etc/sops/age/keys.txt";

    environment.systemPackages = with pkgs; [
      yubikey-manager
      age
      age-plugin-yubikey
      sops
    ];

    services.udev.packages = [ pkgs.yubikey-personalization ];
  };
}