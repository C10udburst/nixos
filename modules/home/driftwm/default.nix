{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.homeSettings.driftwm;

  renderUtils = import ../../render-template.nix {inherit pkgs config lib;};
  renderJinja2 = renderUtils.renderJinja2;
  cleanColors = renderUtils.cleanColors;

  templateData =
    cleanColors
    // {
      font = config.stylix.fonts.monospace.name or "monospace";
      extracmds = cfg.extracmds;
      xwayland_satellite_path = "${lib.getExe pkgs.xwayland-satellite}";
      mobile = config.hostSettings.mobile or false;
      touchscreen = config.hostSettings.touchscreen or false;
      slow = config.hostSettings.slow or false;
      extra_config = cfg.extraConfig;
      extra_bindings = concatStringsSep "\n" (
        flatten (
          map (i: [
            "\"mod+${toString i}\" = \"go-to-bookmark area-${toString i}\""
            "\"mod+shift+${toString i}\" = \"set-bookmark area-${toString i}\""
          ]) (range 0 9)
        )
      );
    };

  renderedConfig = renderJinja2 "config.toml" ./config.toml.j2 templateData;
  renderedShader = renderJinja2 "background.glsl" ./background.glsl.j2 templateData;
in {
  imports = [
    ./noctalia.nix
  ];

  options.homeSettings.driftwm = {
    enable = mkEnableOption "driftwm";
    extracmds = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra commands to run on startup";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra TOML configuration appended to driftwm config.toml";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      [
        pkgs.kdePackages.konsole
      ]
      ++ optionals (config.hostSettings.touchscreen or false) [
        pkgs.wvkbd
        pkgs.wlr-randr
        pkgs.iio-sensor-proxy
      ];

    qt.qt5ctSettings.Appearance.icon_theme = "breeze-dark";
    qt.qt6ctSettings.Appearance.icon_theme = "breeze-dark";

    xdg.configFile = {
      "driftwm/background.glsl".source = renderedShader;
      "driftwm/config.toml".source = renderedConfig;
      "xdg-desktop-portal/driftwm-portals.conf".text = ''
        [preferred]
        default=kde
        org.freedesktop.impl.portal.ScreenCast=wlr
        org.freedesktop.impl.portal.Screenshot=wlr
      '';
    };

    home.sessionVariables = {
      #QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
      QT_QPA_PLATFORM = "wayland;xcb";
      QS_ICON_THEME = "breeze-dark";
    };

    systemd.user.services.driftwm = {
      Unit = {
        Description = "driftwm compositor";
        BindsTo = "graphical-session.target";
        Before = "graphical-session.target";
        Wants = "graphical-session-pre.target";
        After = "graphical-session-pre.target";
      };
      Service = {
        Slice = "session.slice";
        Type = "notify";
        NotifyAccess = "main";
        UnsetEnvironment = "WAYLAND_DISPLAY DISPLAY WAYLAND_SOCKET";
        Environment = "XKB_DEFAULT_LAYOUT=pl";
        ExecStart = "${pkgs.driftwm}/bin/driftwm --backend udev";
      };
    };
  };
}
