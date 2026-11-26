{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.gui.apps.viewers.okular;
  viewersEnabled = config.features.gui.apps.viewers.enable;

  inherit (helpers) cleanColors;

  # Okular stores colours as "r,g,b" triples, so decode the palette's hex values.
  hexDigit = c:
    builtins.getAttr c {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      a = 10;
      b = 11;
      c = 12;
      d = 13;
      e = 14;
      f = 15;
    };
  hexByte = byte: hexDigit (lib.substring 0 1 byte) * 16 + hexDigit (lib.substring 1 1 byte);
  toRgb = value: let
    hex = lib.toLower (lib.removePrefix "#" value);
  in
    if builtins.match "[0-9a-f]{6}" hex == null
    then value
    else
      lib.concatStringsSep "," (
        map (offset: builtins.toString (hexByte (lib.substring offset 2 hex))) [0 2 4]
      );

  darkColor = toRgb (
    if cfg.darkColor != null
    then cfg.darkColor
    else cleanColors.base05
  );
  lightColor = toRgb (
    if cfg.lightColor != null
    then cfg.lightColor
    else cleanColors.base00
  );

  # Okular reads its settings from ~/.config/okularpartrc: the dark colour replaces the
  # document's dark (text) pixels and the light colour its paper, but only once the
  # Recolor render mode is active.
  settings =
    [
      {
        group = "Dlg Accessibility";
        key = "RecolorForeground";
        value = darkColor;
      }
      {
        group = "Dlg Accessibility";
        key = "RecolorBackground";
        value = lightColor;
      }
    ]
    ++ lib.optionals cfg.recolor [
      {
        group = "Document";
        key = "ChangeColors";
        value = "true";
      }
      {
        group = "Document";
        key = "RenderMode";
        value = "Recolor";
      }
    ];

  writes =
    lib.concatMapStringsSep "\n" (
      s: "kwriteconfig6 --file okularpartrc --group \"${s.group}\" --key ${s.key} \"${s.value}\" || true"
    )
    settings;

  applyTheme = pkgs.writeShellScript "okular-apply-theme" ''
    PATH=${lib.getBin pkgs.kdePackages.kconfig}/bin:$PATH
    ${writes}
  '';

  okularCustom = pkgs.symlinkJoin {
    name = "okular-custom";
    paths = [pkgs.kdePackages.okular];
    nativeBuildInputs = [pkgs.makeWrapper pkgs.gnused];
    postBuild = ''
      rm -f $out/bin/okular
      makeWrapper ${pkgs.kdePackages.okular}/bin/okular $out/bin/okular \
        --run ${applyTheme}

      rm -f $out/share/applications/org.kde.okular.desktop
      sed "s|^Exec=okular |Exec=$out/bin/okular |" \
        ${pkgs.kdePackages.okular}/share/applications/org.kde.okular.desktop \
        > $out/share/applications/org.kde.okular.desktop
    '';
  };

  okularMimes = lib.filterAttrs (
    name: value:
      !(builtins.any (
          desktopFile:
            lib.hasSuffix "tiff.desktop" desktopFile
            || lib.hasSuffix "txt.desktop" desktopFile
            || lib.hasSuffix "md.desktop" desktopFile
        )
        value)
      && name != "image/tiff"
  ) (helpers.associatePackage pkgs.kdePackages.okular);
in {
  options.features.gui.apps.viewers.okular = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = viewersEnabled && true;
    };

    recolor = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    darkColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    lightColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.cloudburst = {
      home.packages = [okularCustom];
      xdg.mimeApps.defaultApplications = okularMimes;
    };
  };
}
