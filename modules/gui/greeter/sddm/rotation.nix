{
  config,
  lib,
  pkgs,
  ...
}: let
  greeterCfg = config.features.gui.greeter;
  cfg = greeterCfg.sddm;
  hasAutologin = (greeterCfg.autologin or null) != null && (greeterCfg.autologin or false) != false;
  sddmEnabled = greeterCfg.enable && cfg.enable && !hasAutologin;

  rotateEnabled = cfg.rotate != "" && cfg.rotate != "0";

  westonTransform = "rotate-${cfg.rotate}";
  wlrTransform = cfg.rotate;
  xrandrRotation =
    if cfg.rotate == "90"
    then "right"
    else if cfg.rotate == "270"
    then "left"
    else if cfg.rotate == "180"
    then "inverted"
    else "normal";

  baseWestonIni = (pkgs.formats.ini {}).generate "weston.ini" {
    libinput = {
      enable-tap = config.services.libinput.mouse.tapping;
      left-handed = config.services.libinput.mouse.leftHanded;
    };
    keyboard = {
      keymap_model = config.services.xserver.xkb.model;
      keymap_layout = config.services.xserver.xkb.layout;
      keymap_variant = config.services.xserver.xkb.variant;
      keymap_options = config.services.xserver.xkb.options;
    };
  };

  westonWrapper = pkgs.writeShellScript "weston-sddm-wrapper" ''
    WESTON_INI="''${XDG_RUNTIME_DIR:-/tmp}/weston-sddm.ini"
    cp -f ${baseWestonIni} "$WESTON_INI"
    chmod +w "$WESTON_INI"

    FOUND=0
    for c in /sys/class/drm/card*-*; do
      if [ -f "$c/status" ] && [ "$(cat "$c/status" 2>/dev/null)" = "connected" ]; then
        outName=$(basename "$c" | sed 's/^card[0-9]*-//')
        printf '\n[output]\nname=%s\ntransform=%s\n' "$outName" "${westonTransform}" >> "$WESTON_INI"
        FOUND=1
      fi
    done

    if [ "$FOUND" -eq 0 ]; then
      for common in DSI-1 eDP-1 LVDS-1 HDMI-A-1 DP-1 Virtual-1; do
        printf '\n[output]\nname=%s\ntransform=%s\n' "$common" "${westonTransform}" >> "$WESTON_INI"
      done
    fi

    exec ${lib.getExe pkgs.weston} --shell=kiosk -c "$WESTON_INI" "$@"
  '';

  rotateScript = pkgs.writeShellScript "sddm-rotate" ''
    # Wayland rotation via wlr-randr (if a wlroots compositor is running)
    (
      for i in $(seq 1 30); do
        if ${pkgs.wlr-randr}/bin/wlr-randr >/dev/null 2>&1; then
          for output in $(${pkgs.wlr-randr}/bin/wlr-randr | ${pkgs.gnugrep}/bin/grep '^[^ ]' | ${pkgs.gawk}/bin/awk '{print $1}'); do
            ${pkgs.wlr-randr}/bin/wlr-randr --output "$output" --transform "${wlrTransform}" || true
          done
          break
        fi
        sleep 0.1
      done
    ) &

    # X11 rotation via xrandr
    if ${pkgs.xrandr}/bin/xrandr >/dev/null 2>&1; then
      for output in $(${pkgs.xrandr}/bin/xrandr | ${pkgs.gnugrep}/bin/grep -w 'connected' | ${pkgs.gawk}/bin/awk '{print $1}'); do
        ${pkgs.xrandr}/bin/xrandr --output "$output" --rotate "${xrandrRotation}" || true
      done

      case "${xrandrRotation}" in
        right) matrix="0 1 0 -1 0 1 0 0 1" ;;
        left) matrix="0 -1 1 1 0 0 0 0 1" ;;
        inverted) matrix="-1 0 1 0 -1 1 0 0 1" ;;
        normal) matrix="1 0 0 0 1 0 0 0 1" ;;
        *) matrix="" ;;
      esac

      if [ -n "$matrix" ]; then
        for dev in $(${pkgs.xinput}/bin/xinput list --name-only 2>/dev/null | ${pkgs.gnugrep}/bin/grep -i 'touch' || true); do
          ${pkgs.xinput}/bin/xinput set-prop "$dev" "Coordinate Transformation Matrix" $matrix 2>/dev/null || true
        done
      fi
    fi
  '';
in {
  options.features.gui.greeter.sddm = {
    rotate = lib.mkOption {
      type = lib.types.str;
      default = "0";
    };
  };

  config = lib.mkIf (sddmEnabled && rotateEnabled) {
    # environment.systemPackages = [
    #   pkgs.wlr-randr
    #   pkgs.xrandr
    #   pkgs.xinput
    # ];

    services.displayManager.sddm = {
      wayland.compositorCommand = lib.mkIf (
        config.services.displayManager.sddm.wayland.compositor == "weston"
      ) "${westonWrapper}";
      setupScript = "${rotateScript}";
      settings = {
        X11 = {
          DisplayCommand = "${rotateScript}";
        };
      };
    };
  };
}
