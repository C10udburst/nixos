{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.compat.wine;
  isGui = config.features.gui.enable or false;

  themeReg = helpers.render "wine-theme.reg" ./_theme.reg.j2 helpers.cleanColors;

  wineInitScript = pkgs.writeShellScriptBin "wine-init" ''
    set -euo pipefail
    unset LD_PRELOAD

    WINEPREFIX="''${WINEPREFIX:-$HOME/.wine}"
    export WINEPREFIX
    WINEARCH="''${WINEARCH:-win64}"
    export WINEARCH

    INIT_MARKER="$WINEPREFIX/.compat_installed"

    if [ ! -f "$INIT_MARKER" ]; then
      echo "Initializing Wine prefix in $WINEPREFIX..."
      mkdir -p "$WINEPREFIX"
      ${pkgs.wineWow64Packages.full}/bin/wineserver -k || true
      ${pkgs.wineWow64Packages.full}/bin/wineboot -u || true

      echo "Installing compatibility runtimes (vcredists, DirectX, DXVK, corefonts, etc.)..."
      PATH="${pkgs.wineWow64Packages.full}/bin:${pkgs.winetricks}/bin:${pkgs.cabextract}/bin:${pkgs.p7zip}/bin:${pkgs.unzip}/bin:${pkgs.zenity}/bin:$PATH" \
        ${pkgs.winetricks}/bin/winetricks -q --unattended \
          vcrun2015_2022 \
          vcrun2013 \
          vcrun2012 \
          vcrun2010 \
          vcrun2008 \
          d3dx9 \
          d3dcompiler_43 \
          d3dcompiler_47 \
          dxvk \
          gdiplus \
          msxml3 \
          msxml6 \
          atmlib \
          corefonts \
          fontsmooth=rgb || true

      touch "$INIT_MARKER"
    fi

    echo "Applying Stylix theme to Wine registry..."
    ${pkgs.wineWow64Packages.full}/bin/wine regedit /s "${themeReg}" || true
    # Ensure any previous drive D: symlink is removed so Wine does not hang
    if [ -d "$WINEPREFIX/dosdevices" ]; then
      rm -f "$WINEPREFIX/dosdevices/d:" "$WINEPREFIX/dosdevices/d::"
    fi
  '';

  wineRunnerScript = pkgs.writeShellScriptBin "wine-runner" ''
    set -euo pipefail
    unset LD_PRELOAD
    export WINEPREFIX="''${WINEPREFIX:-$HOME/.wine}"
    export WINEARCH="''${WINEARCH:-win64}"

    ${wineInitScript}/bin/wine-init

    if [ $# -gt 0 ]; then
      exec ${pkgs.wineWow64Packages.full}/bin/wine start /unix "$@"
    fi
  '';
in {
  options.features.compat.wine = lib.mkOption {
    type = lib.types.bool;
    default = config.features.compat.enable && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [
      pkgs.wineWow64Packages.full
      pkgs.winetricks
    ];

    home-manager.users.cloudburst = {
      home.packages = [
        wineInitScript
        wineRunnerScript
      ];

      systemd.user.services.wine-init = {
        Unit = {
          Description = "Initialize Wine prefix";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${wineInitScript}/bin/wine-init";
          RemainAfterExit = true;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };

      xdg.desktopEntries = lib.mkIf isGui {
        wine = {
          name = "Wine Windows Program Loader";
          genericName = "Windows Emulator";
          comment = "Run Windows applications with Wine";
          exec = "${wineRunnerScript}/bin/wine-runner %f";
          icon = "wine";
          mimeType = [
            "application/x-ms-dos-executable"
            "application/x-msi"
            "application/x-ms-shortcut"
            "application/x-bat"
          ];
          categories = [
            "Utility"
            "Emulator"
          ];
        };
      };

      xdg.mimeApps.defaultApplications = lib.mkIf isGui {
        "application/x-ms-dos-executable" = ["wine.desktop"];
        "application/x-msi" = ["wine.desktop"];
        "application/x-ms-shortcut" = ["wine.desktop"];
        "application/x-bat" = ["wine.desktop"];
      };
    };
  };
}
