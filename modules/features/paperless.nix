{ self, inputs, ... }: {
  flake.nixosModules.paperless = { lib, pkgs, config, ... }: {

    # Declared at module level — sibling of services.paperless, not inside it.
    sops.secrets.paperless_admin_password = { owner = "paperless"; };

    services.paperless = {
      enable = true;
      dataDir = "/mnt/cache/paperless/data";
      mediaDir = "/mnt/cache/paperless/media";
      consumptionDir = "/mnt/cache/paperless/consume";

      settings = {
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TIME_ZONE = "Europe/Brussels";
        PAPERLESS_URL = "http://paperless.home";
        PAPERLESS_ALLOWED_HOSTS = "paperless.home,localhost";
      };

      passwordFile = config.sops.secrets.paperless_admin_password.path;
    };

  };
}