{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.wine;

  wineInitScript = pkgs.writeShellScriptBin "wine-init" ''
    set -euo pipefail

    WINEPREFIX="''${WINEPREFIX:-$HOME/.wine}"
    export WINEPREFIX

    INIT_MARKER="$WINEPREFIX/.compat_installed"

    if [ ! -f "$INIT_MARKER" ]; then
      echo "Initializing Wine prefix in $WINEPREFIX..."
      mkdir -p "$WINEPREFIX"
      WINEDLLOVERRIDES="mscoree,mshtml=" ${pkgs.wineWow64Packages.full}/bin/wineboot -u || true

      echo "Installing compatibility runtimes (vcredists, corefonts, etc.)..."
      PATH="${pkgs.wineWow64Packages.full}/bin:${pkgs.winetricks}/bin:${pkgs.cabextract}/bin:${pkgs.p7zip}/bin:${pkgs.unzip}/bin:${pkgs.zenity}/bin:$PATH" \
        ${pkgs.winetricks}/bin/winetricks -q --unattended \
          vcrun2022 \
          vcrun2013 \
          vcrun2012 \
          vcrun2010 \
          vcrun2008 \
          corefonts \
          fontsmooth=rgb \
          msxml6 \
          msxml3 \
          gdiplus \
          atmlib \
          d3dx9 \
          d3dcompiler_47 || true

      touch "$INIT_MARKER"
    fi

    mkdir -p "$WINEPREFIX/dosdevices"

    # Check if /mnt/dane is currently mounted without triggering systemd automount
    FSTYPE=$(${pkgs.util-linux}/bin/findmnt -rn -o FSTYPE /mnt/dane 2>/dev/null || true)
    if [ -n "$FSTYPE" ] && [ "$FSTYPE" != "autofs" ]; then
      ln -snf "/mnt/dane" "$WINEPREFIX/dosdevices/d:"
      echo "Mapped /mnt/dane to Wine drive D:"
    else
      if [ -L "$WINEPREFIX/dosdevices/d:" ]; then
        rm -f "$WINEPREFIX/dosdevices/d:"
        echo "Removed Wine drive D: symlink (unmounted or offline)"
      fi
    fi
  '';

  wineRunnerScript = pkgs.writeShellScriptBin "wine-runner" ''
    set -euo pipefail

    ${wineInitScript}/bin/wine-init

    if [ $# -gt 0 ]; then
      exec ${pkgs.wineWow64Packages.full}/bin/wine start /unix "$@"
    fi
  '';
in {
  options.homeSettings.wine = {
    enable = lib.mkEnableOption "Wine user environment and desktop integration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      wineInitScript
      wineRunnerScript
    ];

    systemd.user.services.wine-init = {
      Unit = {
        Description = "Initialize Wine prefix and drive D: mapping";
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

    xdg.desktopEntries.wine = {
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
}
