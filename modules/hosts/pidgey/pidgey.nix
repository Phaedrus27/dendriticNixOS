# pidgey — network infrastructure host
#
# Aspects:
#   base               sops host key, fleet sshKeys, monitoring, tailscale base
#   sops               secret decryption via the host SSH key
#   pidgeyHardware     Pi 5 + USB SSD boot
#   pidgeyDNS          Pi-hole — adblock + region-TLD (.kanto/.johto/…) resolution
#   tailscaleGateway   subnet router + exit node + split-DNS target
#   tang               LAN-only LUKS key server
#   ntp                chrony time server for the fleet
{ self, inputs, ... }:
{
  flake.nixosConfigurations.pidgey = inputs.nixos-raspberrypi.lib.nixosSystem {
    modules = [ self.nixosModules.pidgeyConfiguration ];
  };

  flake.nixosModules.pidgeyConfiguration = { ... }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.sops
      self.nixosModules.pidgeyHardware
      self.nixosModules.pidgeyDNS
      self.nixosModules.tailscaleGateway
      self.nixosModules.tang
      self.nixosModules.ntp
    ];

    # Not a workstation, so pidgey defines its own admin user; the fleet sk-keys
    # are authorized in base.nix.
    users.users.phaedrus = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    networking = {
      hostName = "pidgey";

      # ──── Static identity ────
      # pidgey is the fleet's DNS (Pi-hole), Tang, and NTP server, so its address
      # cannot depend on the DHCP/DNS it itself provides. end0 is the Pi 5 onboard
      # NIC. No NetworkManager: a single-NIC infra node is simplest on the
      # scripted backend with a fixed address.
      useDHCP = false;
      interfaces.end0.ipv4.addresses = [
        { address = "192.168.1.5"; prefixLength = 24; }
      ];
      defaultGateway = "192.168.1.1";

      # Resolve via upstream, never pidgey's own Pi-hole: keeps name resolution
      # (channel updates, container pulls) working when the pihole container is
      # down, and avoids a boot-time dependency on itself.
      nameservers = [ "1.1.1.1" "9.9.9.9" ];

      firewall.enable = true;
    };

    # Headless infra node — SSH is the only console. Hardening lives in base.nix.
    services.openssh.enable = true;

    # phaedrus has no password (key-only SSH login), so a password sudo prompt
    # would lock out admin entirely. Access is already gated at the SSH door by
    # FIDO2 sk-keys; matches squirtle's headless posture.
    security.sudo.wheelNeedsPassword = false;

    # pidgey is scoped out of the high-value secret set, so it joins the tailnet
    # manually (`tailscale up`) at bring-up rather than via a sops authkey it is
    # not a recipient for.

    # No data-bearing services run here, so there is no restic target; the only
    # durable state is this configuration, tracked in git.
    system.stateVersion = "25.11";
  };
}