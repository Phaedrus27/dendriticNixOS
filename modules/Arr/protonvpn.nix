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
      # Copy config to temp file
      install -m 600 ${config.sops.secrets.protonvpn_wireguard.path} /tmp/wg-vpn.conf
      # Bring up WireGuard in the namespace
      ${pkgs.iproute2}/bin/ip netns exec vpn \
        ${pkgs.wireguard-tools}/bin/wg-quick up /tmp/wg-vpn.conf
    '';
    ExecStop = pkgs.writeShellScript "wg-vpn-stop" ''
      ${pkgs.iproute2}/bin/ip netns exec vpn \
        ${pkgs.wireguard-tools}/bin/wg-quick down /tmp/wg-vpn.conf
    '';
  };
};

    environment.systemPackages = with pkgs; [
      wireguard-tools
      iproute2
    ];
  };
}