{ self, inputs, ... }: {
  perSystem = { pkgs, lib, self', niriCommonSettings, niriSwayidleBase, ... }: {
    packages.myNiriCharizard = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = lib.recursiveUpdate niriCommonSettings {
        outputs = {
          "DP-1" = {
            mode = "2560x1440@239.970";
            scale = 1.0;
            position = _: { props = { x = 0; y = 620; }; };
            # VRR off by default (flicker-free); toggled on demand via Mod+Shift+V
          };
          "HDMI-A-1" = {
            mode = "2560x2880@59.967";
            scale = 1.25;
            position = _: { props = { x = 2560; y = 0; }; };
          };
        };

        # corectrl only enforces its saved GPU profile while running, so start it
        # minimised to the tray at login. Appended to the base list rather than
        # set directly: recursiveUpdate REPLACES lists (it only merges attrsets),
        # so a bare assignment here would drop Noctalia + the swayidle entry that
        # niriCommonSettings defines.
        #
        # Swap the shared swayidle invocation for its lock-free base: this box
        # hosts headless game streaming, LUKS covers at-rest theft, and auto-lock
        # only ever blocked a remote Moonlight wake-into-stream. Match on the
        # swayidle binary (not list position) so it survives future base-arg
        # changes; every other shared entry flows through untouched.
        spawn-at-startup =
          (map (e:
            if lib.isList e && lib.elem (lib.getExe pkgs.swayidle) e
            then niriSwayidleBase
            else e)
            niriCommonSettings.spawn-at-startup)
          ++ [
            [ "corectrl" "--minimize-systray" ]
          ];

        binds."Mod+Shift+V" = _: {
          props.hotkey-overlay-title = "Toggle VRR (DP-1)";
          content.spawn-sh = "vrr-toggle";
        };
      };
    };
  };

  flake.nixosModules.charizardNiri = { pkgs, lib, ... }: {
    programs.niri.package =
      lib.mkForce self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriCharizard;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "vrr-toggle" ''
        out="DP-1"
        if niri msg outputs \
          | awk -v o="($out)" 'index($0,o){f=1} f && /Variable refresh rate:/{print; exit}' \
          | grep -q 'enabled'; then
          niri msg output "$out" vrr off
          ${pkgs.libnotify}/bin/notify-send -t 1500 "VRR disabled" "$out"
        else
          niri msg output "$out" vrr on
          ${pkgs.libnotify}/bin/notify-send -t 1500 "VRR enabled" "$out"
        fi
      '')
    ];
  };
}