# pidgey — network infrastructure host
#
# Two configurations share one identity (pidgeyCore):
#   pidgey-stage1   bootstrap image: core only — no sops, no service stack.
#                   Built as a flashable image; pidgey is not yet a secrets
#                   recipient, so nothing in it may reference sops paths.
#   pidgey          full stack, deployed once the host key is enrolled.
#
# Aspects:
#   base               fleet sshKeys, tailscale client, nix policy
#   pidgeyHardware     Pi 5 + NVMe root (nixos-raspberrypi)
#   sops               secret decryption via host SSH key      (stage 2 only)
#   pidgeyDNS          Pi-hole — adblock + region-TLD resolution (stage 2 only)
#   tailscaleGateway   subnet router + exit node + split-DNS    (stage 2 only)
#   tang               LAN-only LUKS key server                 (stage 2 only)
#   ntp                chrony time server for the fleet         (stage 2 only)
#
# Stage-1 image build (on charizard; needs its aarch64 binfmt):
#   nix build .#nixosConfigurations.pidgey-stage1.config.system.build.sdImage
{ self, inputs, ... }:
{
  # nixos-raspberrypi's nixosSystem (not nixpkgs'): injects the flake ref the
  # board modules expect, and builds against nixos-raspberrypi's locked
  # nixpkgs — which is what its binary cache is populated from.
  flake.nixosConfigurations = {
    pidgey = inputs.nixos-raspberrypi.lib.nixosSystem {
      modules = [ self.nixosModules.pidgeyConfiguration ];
    };
    pidgey-stage1 = inputs.nixos-raspberrypi.lib.nixosSystem {
      modules = [ self.nixosModules.pidgeyStage1 ];
    };
  };

  # ──── Stage 1: bootstrap image ────
  flake.nixosModules.pidgeyStage1 = { ... }: {
    imports = [
      self.nixosModules.pidgeyCore
      # Emits config.system.build.sdImage: partitioned flashable image with
      # the firmware partition pre-populated; root expands on first boot.
      inputs.nixos-raspberrypi.nixosModules.sd-image
    ];

    # Raw .img rather than .img.zst — this image gets dd'd twice (USB stick,
    # then NVMe from inside the USB session), so skip two decompressions.
    sdImage.compressImage = false;
  };

  # ──── Stage 2: full service stack ────
  flake.nixosModules.pidgeyConfiguration = { ... }: {
    imports = [
      self.nixosModules.pidgeyCore
      self.nixosModules.sops
      self.nixosModules.pidgeyDNS
      self.nixosModules.tailscaleGateway
      self.nixosModules.tang
      self.nixosModules.ntp
      self.nixosModules.monitoring
    ];
  };

  # ──── Shared identity: everything both stages must agree on ────
  flake.nixosModules.pidgeyCore = { pkgs, ... }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.pidgeyHardware
    ];

    # EEPROM tooling on the box itself: boot-order surgery during recovery
    # shouldn't depend on network access to fetch the tool.
    environment.systemPackages = [ pkgs.raspberrypi-eeprom ];

    # Not a workstation, so pidgey defines its own admin user; the fleet
    # sk-keys are authorized in base.nix.
    users.users.phaedrus = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    # Monitoring's webhook declaration defaults to secrets.yaml, which pidgey
    # is deliberately not a recipient of; the webhook is duplicated into
    # pidgey.yaml (accepted trade: pidgey compromise burns one webhook —
    # rotate on any incident).
    sops.secrets.discord_webhook.sopsFile = "${self}/modules/secrets/pidgey.yaml";

    dendriticNixOS.monitoring = {
      discordUsername = "Pidgey";
      # tangd deliberately unwatched: socket-activated per-connection
      # template units don't fit the is-active polling model. Revisit
      # with the clevis enrollment project.
      watchedServices = [ "podman-pihole" "chronyd" "tailscaled" ];
      watchedNvme = [ "/dev/nvme0n1" ];
      watchedFilesystems = [ { mount = "/"; high = 85; low = 75; } ];
    };

    # Rebuild-from-origin, self-hosted: the deploy command ships inside the
    # config it deploys. --refresh bypasses nix's flake tarball cache, which
    # serves stale GitHub content for up to an hour otherwise.
    environment.shellAliases.pidgey-up =
      "sudo nixos-rebuild switch --refresh --flake github:Phaedrus27/dendriticNixOS#pidgey";

    networking = {
      hostName = "pidgey";

      # ──── Static identity ────
      # pidgey is the fleet's DNS (Pi-hole), Tang, and NTP server, so its
      # address cannot depend on the DHCP/DNS it itself provides. end0 is the
      # Pi 5 onboard NIC. No NetworkManager: a single-NIC infra node is
      # simplest on the scripted backend with a fixed address.
      useDHCP = false;
      interfaces.end0.ipv4.addresses = [
        { address = "192.168.1.16"; prefixLength = 24; }
      ];
      defaultGateway = "192.168.1.1";

      # Resolve via upstream, never pidgey's own Pi-hole: keeps resolution
      # (channel updates, container pulls) working when the pihole container
      # is down, and avoids a boot-time dependency on itself.
      nameservers = [ "1.1.1.1" "9.9.9.9" ];

      firewall.enable = true;
    };

      # pidgey must never accept tailnet DNS: the tailnet's global nameserver IS
      # pidgey's pi-hole, and self-resolution via the container creates a boot/
      # restart deadlock (host DNS dies whenever the podman container is down).
      services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

    # Headless infra node — SSH is the only console. Hardening lives in base.
    services.openssh.enable = true;

    # phaedrus has no password (key-only SSH), so a password sudo prompt would
    # lock out admin entirely. Access is already gated at the SSH door by
    # FIDO2 sk-keys; matches squirtle's headless posture.
    security.sudo.wheelNeedsPassword = false;

    # WHY: deploys are pushed from charizard as phaedrus; without trusted-user
    # status, locally-built (unsigned) store paths are refused by the daemon
    # and any deploy whose delta isn't fully cache-substitutable fails.
    # trusted-users is root-equivalent for the nix daemon — acceptable here:
    # phaedrus is the sole admin and already wheel on this host.
    nix.settings.trusted-users = [ "phaedrus" ];

    # pidgey is scoped out of the high-value secret set, so it joins the
    # tailnet manually (`tailscale up`) at bring-up, not via a sops authkey.

    # Durable state: this configuration (git) plus /var/lib/tang — the tang
    # keypair there is pinned by charizard's committed JWE. Loss is low-stakes
    # (charizard falls back to FIDO2/passphrase, then re-run clevis encrypt
    # against the regenerated keys), so still no restic target; accepted trade.
    system.stateVersion = "25.11";
  };
}