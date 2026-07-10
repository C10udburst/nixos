{
  config,
  lib,
  pkgs,
  inputs,
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
      font = config.stylix.fonts.monospace.name or "JetBrainsMono Nerd Font";
      extracmds = cfg.extracmds;
      xwayland_satellite_path = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
    };

  renderedConfig = renderJinja2 "config.toml" ./config.toml.j2 templateData;
  renderedShader = renderJinja2 "background.glsl" ./background.glsl.j2 templateData;
  renderedNoctalia = renderJinja2 "noctalia.json" ./noctalia.json.j2 (
    templateData
    // {
      volume_sfx_path = "${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo/audio-volume-change.oga";
    }
  );
in {
  imports = [
    inputs.driftwm-noctalia.homeModules.default
  ];

  options.homeSettings.driftwm = {
    enable = mkEnableOption "driftwm";
    extracmds = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra commands to run on startup";
    };
  };

  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;

      settings = {
        confirm_os_window_close = 0;
      };
    };

    xdg.configFile = {
      "qt5ct/qt5ct.conf".text = ''
        [Appearance]
        icon_theme=breeze-dark
      '';
      "qt6ct/qt6ct.conf".text = ''
        [Appearance]
        icon_theme=breeze-dark
      '';
    };

    home.sessionVariables = {
      #QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
      QT_QPA_PLATFORM = "wayland;xcb";
      QS_ICON_THEME = "breeze-dark";
    };

    programs.noctalia-shell = {
      enable = true;
      settings = mkForce renderedNoctalia;
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

    xdg.configFile."driftwm/background.glsl".source = renderedShader;
    xdg.configFile."driftwm/config.toml".source = renderedConfig;
    xdg.configFile."xdg-desktop-portal/driftwm-portals.conf".text = ''
      [preferred]
      default=kde
      org.freedesktop.impl.portal.ScreenCast=wlr
      org.freedesktop.impl.portal.Screenshot=wlr
    '';
  };
}
