{ self, inputs, ... }: {
  flake.nixosModules.samba = { pkgs, ... }: {

    # ──── Global ────
    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "squirtle";
          "security" = "user";
          "guest ok" = "no";
        };

        # ──── Shares ────
        storage = {
          "path" = "/mnt/storage";
          "browseable" = "yes";
          "read only" = "no";
          "valid users" = "phaedrus";
        };

        # Scratch tier, read-only. phaedrus is not in the media group, so
        # SMB writes would arrive with no group membership over a tree
        # qbittorrent owns — and the tier's cleanup path assumes qbit owns
        # everything it wrote. Browse and copy off, prune on the box.
        scratch-downloads = {
          "path" = "/mnt/scratch/downloads";
          "browseable" = "yes";
          "read only" = "yes";
          "valid users" = "phaedrus";
        };
      };
    };

    # WHY: /mnt/scratch is nofail, so a missing or late SSD leaves an empty
    # directory on root rather than a failed boot — and smbd would serve that
    # empty directory as the share without erroring. Gate the daemon on the
    # mount so the failure mode is "share unavailable", not "share empty".
    systemd.services.samba-smbd.unitConfig.RequiresMountsFor = [
      "/mnt/scratch"
      "/mnt/storage"
    ];

    # ──── Discovery ────
    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}