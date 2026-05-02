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
          ${pkgs.iproute2}/bin/ip netns exec vpn ${pkgs.iproute2}/bin/ip link set lo up
          ${pkgs.iproute2}/bin/ip link add wg-vpn type wireguard
          ${pkgs.iproute2}/bin/ip link set wg-vpn netns vpn
          ${pkgs.wireguard-tools}/bin/wg setconf wg-vpn ${config.sops.secrets.protonvpn_wireguard.path}
          ${pkgs.iproute2}/bin/ip -n vpn addr add $(${pkgs.wireguard-tools}/bin/wg show wg-vpn | grep "interface" -A5 | grep "address" | awk '{print $2}') dev wg-vpn
          ${pkgs.iproute2}/bin/ip -n vpn link set wg-vpn up
          ${pkgs.iproute2}/bin/ip -n vpn route add default dev wg-vpn
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