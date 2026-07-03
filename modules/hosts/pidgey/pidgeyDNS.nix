{ self, ... }:
{
  flake.nixosModules.pidgeyDNS =
    { config, lib, pkgs, ... }:
    let
      # ──── Region records ────
      # Forward records per region TLD. Hosts currently share the flat
      # 192.168.1.0/24; server records move into the johto block when the
      # servers VLAN (192.168.10.0/24) goes live.
      kantoRecords = {
        "unifi.kanto"    = "192.168.1.1";
        "pidgey.kanto"   = "192.168.1.16";
        "squirtle.kanto" = "192.168.1.7";
      };

      johtoRecords = {
        # Populated at servers-VLAN cutover (192.168.10.x):
        #   pidgey.johto / squirtle.johto / bulbasaur.johto / abra.johto
      };

      hoennRecords = {
        # Populated as IoT devices receive static leases.
      };

      # ──── Service records — .home (function) ────
      # .home is the permanent, region-neutral service domain.
      # Services are consumed by apps, bookmarks, and household devices that
      # are expensive to repoint, so their names never encode location; when
      # a service moves hosts or VLANs, only the IP here changes. Kanto LAN
      # IPs (not Tailscale 100.x): LAN clients connect directly, remote
      # tailnet clients reach the same addresses via pidgey's advertised
      # subnet route — one record set, no DERP detours.
      homeRecords = {
        "radarr.home"      = "192.168.1.7";
        "sonarr.home"      = "192.168.1.7";
        "prowlarr.home"    = "192.168.1.7";
        "bazarr.home"      = "192.168.1.7";
        "jellyfin.home"    = "192.168.1.7";
        "qbittorrent.home" = "192.168.1.7";
        "paperless.home"   = "192.168.1.7";
        "squirtle.home"    = "192.168.1.7";
        "unifi.home"       = "192.168.1.1";
        "pidgey.home"      = "192.168.1.16";
      };

      allRecords = kantoRecords // johtoRecords // hoennRecords // homeRecords;

      regionsConf = pkgs.writeText "05-regions.conf"
        (lib.concatStringsSep "\n"
          (lib.mapAttrsToList (host: ip: "address=/${host}/${ip}") allRecords));
    in
    {
      # ──── Pi-hole container ────
      # Pi-hole has no NixOS module; it runs as a pinned OCI container on host
      # networking so FTL binds :53 directly on the LAN interface.
      virtualisation.oci-containers.containers.pihole = {
        image = "pihole/pihole:2026.06.0"; # pin to a release tag; never :latest
        extraOptions = [ "--network=host" ];

        environment = {
          TZ = "Europe/Brussels";
          # Answer on every interface the host networking namespace exposes.
          FTLCONF_dns_listeningMode = "all";
          # Make FTL read the custom records mounted into /etc/dnsmasq.d.
          FTLCONF_misc_etc_dnsmasq_d = "true";
        };

        # Supplies FTLCONF_webserver_api_password; kept out of the Nix store.
        environmentFiles = [ config.sops.secrets.pihole_webpassword.path ];

        volumes = [
          "/var/lib/pihole/etc-pihole:/etc/pihole"
          "${regionsConf}:/etc/dnsmasq.d/05-regions.conf:ro"
        ];
      };

      # podman does not create missing bind-mount sources (docker does);
      # Pi-hole's persistent state directory must exist before first start.
      systemd.tmpfiles.rules = [ "d /var/lib/pihole/etc-pihole 0750 root root -" ];

       # pidgey's only secret; lives in its own low-value file encrypted to
       # pidgey + admin YubiKeys, keeping it out of the fleet's high-value
       # secrets.yaml (which pidgey is deliberately NOT a recipient of).
       sops.secrets.pihole_webpassword.sopsFile = "${self}/modules/secrets/pidgey.yaml";

      # DNS (53) and the admin UI (80) on the LAN NIC only.
      networking.firewall.interfaces."end0" = {
        allowedTCPPorts = [ 53 80 ];
        allowedUDPPorts = [ 53 ];
      };
    };
}