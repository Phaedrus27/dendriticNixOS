{ self, inputs, ... }: {
  flake.nixosModules.charizardHardware = { config, lib, pkgs, modulesPath, ... }: {
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

    # ── Boot & initrd ────────────────────────────────────────────────────────
    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    boot.kernelParams = [
      "amd_pstate=active"                  # EPP-based freq scaling (Zen 3+)
      "amdgpu.ppfeaturemask=0xffffffff"    # unlock GPU OC/UV/fan controls
    ];

    # Required for FIDO2 LUKS unlock at boot
    boot.initrd.systemd.enable = true;
    boot.initrd.luks.fido2Support = false;
    boot.initrd.luks.devices."luks-bb59877a-e6fb-443d-af1e-485147ca43f2" = {
      device = "/dev/disk/by-uuid/bb59877a-e6fb-443d-af1e-485147ca43f2";
      crypttabExtraOpts = [ "fido2-device=auto" ];
    };

    # ── Filesystems ──────────────────────────────────────────────────────────
    fileSystems."/" = {
      device = "/dev/mapper/luks-bb59877a-e6fb-443d-af1e-485147ca43f2";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/F022-0675";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    fileSystems."/mnt/data" = {
      device = "/dev/disk/by-uuid/df31339b-c019-422f-a330-51a42c4d54ae";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };

    swapDevices = [ ];

    # ── Platform & firmware ──────────────────────────────────────────────────
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # ── CPU power & frequency scaling ────────────────────────────────────────
    powerManagement.cpuFreqGovernor = "schedutil";

    systemd.services.amd-epp = {
      description = "Set AMD Energy Performance Preference";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "set-epp" ''
          for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
            echo balance_performance > "$cpu"
          done
        '';
      };
    };

    systemd.services.ryzenadj = {
      description = "Apply RyzenAdj CPU power limits";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ryzenadj-apply" ''
          ${pkgs.ryzenadj}/bin/ryzenadj \
            --stapm-limit=65000 \
            --fast-limit=75000 \
            --slow-limit=65000 \
            --tctl-temp=85
        '';
      };
    };

    # ── GPU (CoreCtrl) ───────────────────────────────────────────────────────
    programs.corectrl = {
      enable = true;
      gpuOverclock.enable = true;
    };
    users.users.phaedrus.extraGroups = [ "corectrl" ];

    # ── Fan control ──────────────────────────────────────────────────────────
    #services.fancontrol = {
      #enable = true;
      # Populate after running: sudo sensors-detect --auto && sudo pwmconfig
      # config = ''
      #   INTERVAL=10
      #   DEVPATH=...
      #   FCTEMPS=...
      #   MINTEMP=...
      #   MAXTEMP=...
      # '';
    #};

    # ── Monitoring & tuning packages ─────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      lm_sensors        # sensors-detect, pwmconfig, fancontrol
      ryzenadj          # CPU power limit tuning
      nvtopPackages.amd # real-time GPU + CPU monitor
      stress-ng         # stability testing
      s-tui             # TUI stress test + live temp/freq view
    ];
  };
}