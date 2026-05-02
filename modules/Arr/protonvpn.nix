{ self, inputs, ... }: {
  flake.nixosModules.protonvpn = { config, lib, pkgs, ... }: {

    sops.secrets.protonvpn_wireguard = {
      format = "yaml";
    };

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
  # Create WireGuard interface in host namespace
  ${pkgs.iproute2}/bin/ip link add wg-vpn type wireguard
  # Move it into the vpn namespace
  ${pkgs.iproute2}/bin/ip link set wg-vpn netns vpn
  # Apply config inside namespace
  ${pkgs.iproute2}/bin/ip netns exec vpn \
    ${pkgs.wireguard-tools}/bin/wg setconf wg-vpn \
    ${config.sops.secrets.protonvpn_wireguard.path}
  # Add IP address inside namespace
  ${pkgs.iproute2}/bin/ip -n vpn addr add 10.2.0.2/32 dev wg-vpn
  # Bring interface up
  ${pkgs.iproute2}/bin/ip -n vpn link set wg-vpn up
  # Add default route through WireGuard
  ${pkgs.iproute2}/bin/ip -n vpn route add default dev wg-vpn
  # Bring up loopback
  ${pkgs.iproute2}/bin/ip -n vpn link set lo up
'';
ExecStop = pkgs.writeShellScript "wg-vpn-stop" ''
  ${pkgs.iproute2}/bin/ip -n vpn link del wg-vpn
'';
  };
};

    environment.systemPackages = with pkgs; [
      wireguard-tools
      iproute2
    ];
  };
}