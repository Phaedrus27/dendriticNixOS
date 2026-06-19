{ self, inputs, ... }: {
  flake.nixosModules.seedbox = { ... }: {
    # VPN-confined download pipeline: wireguard netns, torrent client
    # inside it, archive extraction feeding the *arrs.
    imports = [
      self.nixosModules.protonvpn
      self.nixosModules.qbittorrent
      self.nixosModules.unpackerr
    ];

    dendriticNixOS.monitoring.watchedServices = [ "qbittorrent" "wg-vpn" ];
  };
}