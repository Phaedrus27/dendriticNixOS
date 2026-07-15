# ─────────────────────────────────────────────────────────────
# emulation.nix — retro console emulation
#
#   Cores       retroarch.withCores — one line per console
#   Config      declared retroarch.cfg keys injected via wrapper
#   Controllers udev uaccess rules for pads
#
# RetroArch over standalone emulators: its flat key-value config
# plus --appendconfig makes the frontend wrappable in the same
# style as niri. DuckStation (the PS1 alternative) was removed
# from nixpkgs at upstream's request and offers no declarative
# config path at all. SwanStation is the GPL fork of DuckStation's
# engine as a libretro core; Beetle rides along as the per-game
# accuracy fallback.
# ─────────────────────────────────────────────────────────────
{
  flake.nixosModules.emulation = { pkgs, lib, ... }:
    let
      # ──── Cores ────
      retroarchWithCores = pkgs.retroarch.withCores (cores: with cores; [
        swanstation   # PS1 — DuckStation-lineage engine, boots BIOS-free via OpenBIOS
        beetle-psx-hw # PS1 — Mednafen-lineage, fallback for titles SwanStation mishandles
      ]);

      # ──── Declared config ────
      # Injected at every launch via --appendconfig: declared keys are
      # authoritative and re-assert over anything saved from the menus,
      # while undeclared keys remain user-tunable and persistable.
      # config_save_on_exit stays off so RetroArch never writes the
      # merged result back over user state when closing.
      # Core options (resolution, PGXP, renderer) are deliberately NOT
      # declared: a store-managed core_options_path would break the
      # per-game .opt override mechanism, and gameplay tuning is
      # iterative per-game state, not infrastructure.
      declaredCfg = pkgs.writeText "retroarch-declared.cfg" (lib.generators.toKeyValue
        { mkKeyValue = k: v: ''${k} = "${v}"''; }
        {
          config_save_on_exit = "false";
          video_driver = "vulkan";
          # Run PAL 50Hz / NTSC 60Hz content at true speed on the VRR panel
          # instead of resampling to the desktop refresh rate.
          vrr_runloop_enable = "true";
          # Store paths: menu assets and pad profiles come from nixpkgs
          # instead of the imperative online-updater download flow.
          # Unrecognized pad? The declarative fix is overriding
          # retroarch-joypad-autoconfig's src with a fork carrying the
          # new mapping (overlay), then upstreaming the profile.
          assets_directory = "${pkgs.retroarch-assets}/share/retroarch/assets";
          joypad_autoconfig_dir = "${pkgs.retroarch-joypad-autoconfig}/share/libretro/autoconfig";
          # Single stable location for the only irreplaceable artifacts
          # (memcards + save states) → one directory to target when the
          # off-site backup question gets its answer.
          savefile_directory = "~/.local/share/retroarch/saves";
          savestate_directory = "~/.local/share/retroarch/states";
        });

      # symlinkJoin + wrapProgram rather than writeShellScriptBin so the
      # package's .desktop entries launch the wrapped binary too.
      retroarch = pkgs.symlinkJoin {
        name = "retroarch-declarative";
        paths = [ retroarchWithCores ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/retroarch \
            --add-flags "--appendconfig=${declaredCfg}"
        '';
      };
    in {
      environment.systemPackages = [ retroarch ];

      # ──── Controllers ────
      # uaccess rules for game devices; pads work for the seated user
      # without membership in input-adjacent groups.
      services.udev.packages = [ pkgs.game-devices-udev-rules ];
    };
}