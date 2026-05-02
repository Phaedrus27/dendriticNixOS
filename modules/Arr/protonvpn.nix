{ self, inputs, ... }: {
  flake.nixosModules.protonvpn = { config, lib, pkgs, ... }: {

    sops.secrets.protonvpn_privkey = {};
    sops.secrets.protonvpn_pubkey = {};
    sops.secrets.protonvpn_endpoint = {};
    sops.secrets.protonvpn_address = {};
    
    # Create the VPN network namespace
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

    # WireGuard interface inside the namespace
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
    '';
  };
};

    environment.systemPackages = with pkgs; [
      wireguard-tools
      iproute2
    ];
  };
}