{ self, inputs, ... }: {
  flake.nixosModules.protonvpn = { config, lib, pkgs, ... }: {
    # Secrets this module consumes. Each resolves against the importing
    # host's defaultSopsFile; sops-nix validates the keys exist at eval.
    sops.secrets.protonvpn_privkey = {};
    sops.secrets.protonvpn_pubkey = {};
    sops.secrets.protonvpn_endpoint = {};
    sops.secrets.protonvpn_address = {};

    systemd.services.netns-vpn = {
      description = "VPN network namespace";
      before = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Idempotent: `ip netns add` fails if the namespace already exists,
        # which it will after an unclean stop (crash, power loss) since
        # ExecStop never ran. Tolerating "already exists" makes every start
        # converge to the same state instead of wedging the unit.
        ExecStart = pkgs.writeShellScript "netns-vpn-start" ''
          ${pkgs.iproute2}/bin/ip netns add vpn 2>/dev/null || true
        '';
        ExecStop = "${pkgs.iproute2}/bin/ip netns del vpn";
      };
    };

    systemd.services.wg-vpn = {
      description = "ProtonVPN WireGuard in VPN namespace";
      after = [ "netns-vpn.service" ];
      requires = [ "netns-vpn.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "wg-vpn-start" ''
          #!${pkgs.bash}/bin/bash
          set -e
          # Idempotency preamble: converge from any partial prior state.
          # `set -e` means a mid-script failure (unreachable endpoint,
          # missing secret) leaves links behind, and the unconditional
          # `ip link add` calls below would then fail with "File exists"
          # on every retry — the unit could never self-heal. Deleting
          # leftovers first makes restart equivalent to first start.
          # wg-vpn may be in the netns (moved) or the host (not yet moved),
          # so try both; deleting veth-host destroys its peer with it.
          ${pkgs.iproute2}/bin/ip -n vpn link del wg-vpn 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip link del wg-vpn 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip link del veth-host 2>/dev/null || true
          # DNS for VPN namespace — use ProtonVPN's DNS, bypass ISP
          ${pkgs.coreutils}/bin/mkdir -p /etc/netns/vpn
          echo "nameserver 10.2.0.1" > /etc/netns/vpn/resolv.conf
          # WireGuard setup
          ${pkgs.iproute2}/bin/ip link add wg-vpn type wireguard
          ${pkgs.iproute2}/bin/ip link set wg-vpn netns vpn
          ${pkgs.iproute2}/bin/ip -n vpn link set lo up
          ${pkgs.iproute2}/bin/ip -n vpn addr add "$(cat ${config.sops.secrets.protonvpn_address.path})" dev wg-vpn
          ${pkgs.iproute2}/bin/ip netns exec vpn \
            ${pkgs.wireguard-tools}/bin/wg set wg-vpn \
              private-key ${config.sops.secrets.protonvpn_privkey.path}
          ${pkgs.iproute2}/bin/ip netns exec vpn \
            ${pkgs.wireguard-tools}/bin/wg set wg-vpn \
              peer "$(cat ${config.sops.secrets.protonvpn_pubkey.path})" \
              allowed-ips "0.0.0.0/0,::/0" \
              endpoint "$(cat ${config.sops.secrets.protonvpn_endpoint.path})" \
              persistent-keepalive 25
          ${pkgs.iproute2}/bin/ip -n vpn link set wg-vpn up
          ${pkgs.iproute2}/bin/ip -n vpn route add default dev wg-vpn
          # veth pair for WebUI access from host
          ${pkgs.iproute2}/bin/ip link add veth-host type veth peer name veth-vpn
          ${pkgs.iproute2}/bin/ip link set veth-vpn netns vpn
          ${pkgs.iproute2}/bin/ip addr add 10.99.0.1/30 dev veth-host
          ${pkgs.iproute2}/bin/ip -n vpn addr add 10.99.0.2/30 dev veth-vpn
          ${pkgs.iproute2}/bin/ip link set veth-host up
          ${pkgs.iproute2}/bin/ip -n vpn link set veth-vpn up
        '';
        ExecStop = pkgs.writeShellScript "wg-vpn-stop" ''
          #!${pkgs.bash}/bin/bash
          ${pkgs.iproute2}/bin/ip -n vpn link del wg-vpn 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip link del veth-host 2>/dev/null || true
          ${pkgs.coreutils}/bin/rm -f /etc/netns/vpn/resolv.conf
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      wireguard-tools
      iproute2
    ];
  };
}
