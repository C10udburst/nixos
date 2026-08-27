{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.wine;

  renderUtils = import ../../render-template.nix {inherit pkgs config lib;};
  renderJinja2 = renderUtils.renderJinja2;
  cleanColors = renderUtils.cleanColors;

  themeReg = renderJinja2 "wine-theme.reg" ./theme.reg.j2 cleanColors;

  wineInitScript = pkgs.writeShellScriptBin "wine-init" ''
    set -euo pipefail
    unset LD_PRELOAD

    WINEPREFIX="''${WINEPREFIX:-$HOME/.wine}"
    export WINEPREFIX

    INIT_MARKER="$WINEPREFIX/.compat_installed"

    if [ ! -f "$INIT_MARKER" ]; then
      echo "Initializing Wine prefix in $WINEPREFIX..."
      mkdir -p "$WINEPREFIX"
      ${pkgs.wine-staging}/bin/wineboot -u || true

      echo "Installing compatibility runtimes (vcredists, DirectX, DXVK, corefonts, etc.)..."
      PATH="${pkgs.wine-staging}/bin:${pkgs.winetricks}/bin:${pkgs.cabextract}/bin:${pkgs.p7zip}/bin:${pkgs.unzip}/bin:${pkgs.zenity}/bin:$PATH" \
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

    # Apply Stylix theme colors to Wine registry
    echo "Applying Stylix theme to Wine registry..."
    ${pkgs.wine-staging}/bin/wine regedit /s "${themeReg}" || true

    mkdir -p "$WINEPREFIX/dosdevices"
    rm -f "$WINEPREFIX/dosdevices/d::"

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
    unset LD_PRELOAD

    ${wineInitScript}/bin/wine-init

    if [ $# -gt 0 ]; then
      exec ${pkgs.wine-staging}/bin/wine start /unix "$@"
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
