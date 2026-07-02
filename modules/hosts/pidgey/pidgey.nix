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
    ];
  };

  # ──── Shared identity: everything both stages must agree on ────
  flake.nixosModules.pidgeyCore = { ... }: {
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

    networking = {
      hostName = "pidgey";

      # ──── Static identity ────
      # pidgey is the fleet's DNS (Pi-hole), Tang, and NTP server, so its
      # address cannot depend on the DHCP/DNS it itself provides. end0 is the
      # Pi 5 onboard NIC. No NetworkManager: a single-NIC infra node is
      # simplest on the scripted backend with a fixed address.
      useDHCP = false;
      interfaces.end0.ipv4.addresses = [
        { address = "192.168.1.5"; prefixLength = 24; }
      ];
      defaultGateway = "192.168.1.1";

      # Resolve via upstream, never pidgey's own Pi-hole: keeps resolution
      # (channel updates, container pulls) working when the pihole container
      # is down, and avoids a boot-time dependency on itself.
      nameservers = [ "1.1.1.1" "9.9.9.9" ];

      firewall.enable = true;
    };

    # Headless infra node — SSH is the only console. Hardening lives in base.
    services.openssh.enable = true;

    # phaedrus has no password (key-only SSH), so a password sudo prompt would
    # lock out admin entirely. Access is already gated at the SSH door by
    # FIDO2 sk-keys; matches squirtle's headless posture.
    security.sudo.wheelNeedsPassword = false;

    # pidgey is scoped out of the high-value secret set, so it joins the
    # tailnet manually (`tailscale up`) at bring-up, not via a sops authkey.

    # No data-bearing services → no restic target; the only durable state is
    # this configuration, tracked in git.
    system.stateVersion = "25.11";
  };
}