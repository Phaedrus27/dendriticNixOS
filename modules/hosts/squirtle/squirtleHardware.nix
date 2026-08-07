{ self, inputs, ... }: {
  flake.nixosModules.squirtleHardware = { config, lib, modulesPath, ... }: {
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

    boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/c5b731cb-0a3a-45e9-b6cf-48beb45e0995";
      fsType = "ext4";
    };

    boot.kernel.sysctl = {
      "net.core.rmem_max" = 7500000;
      "net.core.wmem_max" = 7500000;
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/2C74-D6A8";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    swapDevices = [ ];
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # ──── Clevis readiness gate ──────────────────────────────────────────────
    # WHY: nixpkgs generates cryptsetup-clevis-<dev> as Type=oneshot with a
    # single `clevis decrypt` and no retry; useTang only orders it after
    # network-online.target, which carrier + a static address satisfy well
    # before the switch port forwards. Since the Flex Mini joined the domain,
    # RSTP reconvergence puts that window inside the ~3s the one attempt has —
    # measured 1 failure in 4 boots (2026-08-07). Wait for tang to actually
    # answer, then let the real attempt run.
    boot.initrd.systemd.extraBin.sleep = "${pkgs.coreutils}/bin/sleep";
    boot.initrd.systemd.services."cryptsetup-clevis-luks-bb59877a-e6fb-443d-af1e-485147ca43f2".preStart = ''
      tries=0
      until curl -sf -o /dev/null --max-time 2 http://192.168.1.16:7654/adv; do
        tries=$((tries + 1))
        if [ "$tries" -ge 20 ]; then
          echo "tang unanswered after $tries attempts, falling through to passphrase"
          break
        fi
        echo "tang not reachable yet (attempt $tries), waiting for the port to forward"
        sleep 1
      done
    '';
  };

}