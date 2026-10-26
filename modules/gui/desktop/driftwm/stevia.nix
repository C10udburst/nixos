{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.desktop.driftwm.stevia;
  driftwmEnabled = config.features.gui.desktop.driftwm.enable;
  touchscreen = config.features.core.hardware.touchscreen or false;
in {
  options.features.gui.desktop.driftwm.stevia = lib.mkOption {
    type = lib.types.bool;
    default = driftwmEnabled && touchscreen;
  };

  config = lib.mkIf cfg {
    nixpkgs.overlays = [
      (final: prev: {
        stevia = prev.stevia.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./_stevia-driftwm-no-zphoc.patch];
          # Stevia hardcodes its dictionary lookup to $out/share/hunspell (and
          # myspell) at configure time and the nixpkgs build ships no dicts, so
          # word suggestions never load. Symlink them in: the pl layout resolves
          # to pl_PL, the us layout to en_US, and en_US doubles as stevia's
          # built-in fallback locale when a dictionary lookup misses.
          postInstall =
            ''
              mkdir -p $out/share/hunspell
              ln -s ${final.hunspellDicts.pl_PL}/share/hunspell/pl_PL.aff $out/share/hunspell/
              ln -s ${final.hunspellDicts.pl_PL}/share/hunspell/pl_PL.dic $out/share/hunspell/
              ln -s ${final.hunspellDicts.en_US}/share/hunspell/en_US.aff $out/share/hunspell/
              ln -s ${final.hunspellDicts.en_US}/share/hunspell/en_US.dic $out/share/hunspell/
            ''
            + (old.postInstall or "");
        });
      })
    ];

    environment.systemPackages = [pkgs.stevia];

    # Toggle the stevia process itself: start it on demand, stop it to make the
    # OSK disappear. Auto-unfold (input-method-v2) still drives visibility while
    # running; double-pressing the OSK forces it shown when needed.
    home-manager.users.cloudburst.home.packages = [
      (pkgs.writeShellScriptBin "osk-toggle" ''
        if ${pkgs.systemd}/bin/systemctl --user is-active --quiet stevia-osk; then
          ${pkgs.systemd}/bin/systemctl --user stop stevia-osk
        else
          ${pkgs.systemd}/bin/systemctl --user start stevia-osk
        fi
      '')
    ];

    # stevia reads layouts from org.gnome.desktop.input-sources (pl, matching the
    # driftwm xkb layout) and its overall on/off state from screen-keyboard-enabled.
    home-manager.users.cloudburst.dconf.settings = {
      "org/gnome/desktop/input-sources" = {
        sources = [
          (lib.gvariant.mkTuple [
            "xkb"
            "pl"
          ])
          (lib.gvariant.mkTuple [
            "xkb"
            "us"
          ])
        ];
      };
      "org/gnome/desktop/a11y/applications" = {
        screen-keyboard-enabled = true;
      };
    };

    home-manager.users.cloudburst.systemd.user.services.stevia-osk = {
      Unit = {
        Description = "Stevia on-screen keyboard";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "dbus";
        BusName = "sm.puri.OSK0";
        ExecStart = "${pkgs.stevia}/bin/phosh-osk-stevia --allow-replacement";
        Restart = "on-failure";
        RestartSec = "1s";
        TimeoutStopSec = "5";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
