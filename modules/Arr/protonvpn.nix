{ self, inputs, ... }: {
  flake.nixosModules.protonvpn = { config, lib, pkgs, ... }: {
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
        ExecStart = "${pkgs.iproute2}/bin/ip netns add vpn";
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
          # DNS for VPN namespace — use ProtonVPN's DNS, bypass ISP
          ${pkgs.coreutils}/bin/mkdir -p /etc/netns/vpn
          echo "nameserver 10.2.0.1" > /etc/netns/vpn/resolv.conf
          # WireGuard setup
          ${pkgs.iproute2}/bin/ip link add wg-vpn type wireguard
          ${pkgs.iproute2}/bin/ip link set wg-vpn netns vpn
          ${pkgs.iproute2}/bin/ip -n vpn link set lo up
          ${pkgs.iproute2}/bin/ip -n vpn addr add "$(cat /run/secrets/protonvpn_address)" dev wg-vpn
          ${pkgs.iproute2}/bin/ip netns exec vpn \
            ${pkgs.wireguard-tools}/bin/wg set wg-vpn \
              private-key /run/secrets/protonvpn_privkey
          ${pkgs.iproute2}/bin/ip netns exec vpn \
            ${pkgs.wireguard-tools}/bin/wg set wg-vpn \
              peer "$(cat /run/secrets/protonvpn_pubkey)" \
              allowed-ips "0.0.0.0/0,::/0" \
              endpoint "$(cat /run/secrets/protonvpn_endpoint)" \
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