{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.desktop.driftwm;
  isSlow = config.features.core.hardware.slow or false;
  isTouchscreen = config.features.core.hardware.touchscreen or false;
  noctaliaEnabled = config.features.gui.desktop.driftwm.noctalia.enable or false;
in {
  options.features.gui.desktop.driftwm = {
    extracmds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.cloudburst = {config, ...}: let
      colors = config.lib.stylix.colors;
      tomlFormat = pkgs.formats.toml {};

      bookmarkBindings = builtins.listToAttrs (
        lib.flatten (
          map (i: [
            {
              name = "mod+${toString i}";
              value = "go-to-bookmark area-${toString i}";
            }
            {
              name = "mod+shift+${toString i}";
              value = "set-bookmark area-${toString i}";
            }
          ]) (lib.range 0 9)
        )
      );

      noctaliaKeybindings = lib.optionalAttrs noctaliaEnabled {
        "mod+tab" = "spawn noctalia msg panel-toggle launcher \"/wind \"";
        "mod+space" = "spawn noctalia msg panel-toggle launcher";
        "mod+return" = "spawn noctalia msg panel-toggle launcher";
        "mod+slash" = "spawn noctalia msg panel-toggle launcher \"/\"";
        "mod+n" = "spawn noctalia msg notifications toggleHistory";
        "mod+v" = "spawn noctalia msg panel-toggle clipboard";
        "mod+period" = "spawn noctalia msg panel-toggle launcher \"/emo \"";
        "mod+alt+period" = "spawn noctalia msg panel-toggle launcher \"/uni \"";
        "mod+escape" = "spawn noctalia msg panel-toggle session";
        "mod+f11" = "spawn noctalia msg bar-toggle main";
        "mod+l" = "spawn noctalia msg session lock";
        "mod+r" = "spawn noctalia msg panel-toggle control-center";
        "mod+m" = "spawn noctalia msg panel-toggle cloudburst/driftwm:minimap";
        "XF86MonBrightnessUp" = "spawn noctalia msg brightness increase";
        "XF86MonBrightnessDown" = "spawn noctalia msg brightness decrease";
      };

      baseKeybindings = {
        "ctrl+alt+t" = "exec konsole";
        "ctrl+shift+escape" = "exec plasma-systemmonitor";
        "XF86Calculator" = "exec qalculate-qt";
        "XF86Search" = "exec brave";
        "XF86WWW" = "exec brave";
        "XF86Mail" = "exec brave https://mail.google.com";

        "XF86AudioRaiseVolume" = "spawn pamixer -i 5";
        "XF86AudioLowerVolume" = "spawn pamixer -d 5";
        "XF86AudioMute" = "spawn pamixer -t";

        "alt+f4" = "close-window";
        "mod+equal" = "zoom-in";
        "mod+minus" = "zoom-out";
        "mod+up" = "center-nearest up";
        "mod+down" = "center-nearest down";
        "mod+left" = "center-nearest left";
        "mod+right" = "center-nearest right";
        "mod+w" = "center-nearest up";
        "mod+s" = "center-nearest down";
        "mod+a" = "center-nearest left";
        "mod+d" = "center-nearest right";
        "mod+q" = "close-window";
        "mod+e" = "exec dolphin";
        "mod+shift+w" = "pan-viewport up";
        "mod+shift+s" = "pan-viewport down";
        "mod+shift+a" = "pan-viewport left";
        "mod+shift+d" = "pan-viewport right";
      };

      windowRules =
        [
          {
            title = "winit window";
            widget = true;
          }
          {
            app_id = "Waydroid";
            decoration = "server";
          }
          {
            app_id = "waydroid.*";
            decoration = "server";
          }
          {
            app_id = "blender";
            pass_mouse = [
              "alt+left"
              "alt+middle"
              "alt+right"
            ];
          }
          {
            app_id = "Mayo";
            pass_mouse = [
              "alt+left"
              "alt+middle"
              "alt+right"
            ];
          }
        ]
        ++ lib.optionals (cfg.desktop or false) [
          {
            app_id = "driftwm.desktop";
            widget = true;
            decoration = "none";
          }
        ]
        ++ lib.optionals isTouchscreen [
          {
            app_id = "wvkbd";
            pinned_to_screen = true;
          }
        ];

      driftwmConfig =
        lib.recursiveUpdate {
          mod_key = "super";
          autostart =
            cfg.extracmds
            ++ lib.optional isTouchscreen "auto-rotate"
            ++ lib.optional noctaliaEnabled "noctalia"
            ++ lib.optional (cfg.desktop or false) "driftwm-desktop";
          window_placement = "auto";
          env = {
            "_JAVA_AWT_WM_NONREPARENTING" = "1";
            "QT_QPA_PLATFORM" = "wayland;xcb";
          };
          input.keyboard = {
            layout = "pl";
            num_lock = true;
          };
          input.mouse = {
            accel_speed = 0.1;
            accel_profile = "adaptive";
          };
          input.trackpad = {
            accel_speed = 0.1;
            click_method = "button_areas";
          };
          cursor.inactive_opacity = 0.25;
          mouse.on-canvas = lib.optionalAttrs noctaliaEnabled {
            "right" = "spawn noctalia msg panel-toggle launcher";
          };
          mouse.anywhere = {
            "ctrl+alt+trackpad-scroll" = "pan-viewport";
            "ctrl+alt+left" = "pan-viewport";
          };
          touch.on-canvas = lib.optionalAttrs noctaliaEnabled {
            "2-finger-tap" = "spawn noctalia msg panel-toggle launcher";
          };
          touch.anywhere = lib.optionalAttrs noctaliaEnabled {
            "4-finger-tap" = "spawn noctalia msg panel-toggle launcher";
          };
          gestures = {
            swipe_threshold = 6;
            on-window = {
              "3-finger-doubletap-swipe" = "none";
              "alt+3-finger-doubletap-swipe" = "move-window";
              "ctrl+alt+3-finger-doubletap-swipe" = "resize-window";
              "ctrl+2-finger-pinch-in" = "zoom-out";
              "ctrl+2-finger-pinch-out" = "zoom-in";
            };
          };
          navigation.edge_pan = {
            zone = 60.0;
            cursor_zone = 10.0;
            speed_min = 1.0;
            speed_max = 6.0;
            cursor_pan = false;
          };
          snap = {
            enabled = true;
            gap = 8;
            distance = 20;
            centers = true;
            corners = true;
          };
          zoom = {
            trackpad_speed = 1.2;
            reset_on_new_window = false;
            reset_on_activation = false;
            fit_padding = 24.0;
          };
          background = {
            type = "shader";
            path = "~/.config/driftwm/background.glsl";
            texture = "${config.stylix.image}";
            animate_fps =
              if isSlow
              then 15
              else 24;
          };
          decorations = {
            title_bar_height = 30;
            bg_color = "#${colors.base00}";
            fg_color = "#${colors.base05}";
            corner_radius = 10;
            border_width = 2;
            border_color = "#${colors.base02}";
            border_color_focused = "#${colors.base0E}";
            shadow = true;
            font = config.stylix.fonts.monospace.name or "JetBrainsMono Nerd Font";
          };
          output.outline = {
            color = "#${colors.base0E}";
            thickness = 1;
          };
          xwayland = {
            enabled = true;
            path = "${lib.getExe pkgs.xwayland-satellite}";
          };
          keybindings = baseKeybindings // bookmarkBindings // noctaliaKeybindings;
          window_rules = windowRules;
        }
        cfg.extraConfig;
    in {
      xdg.configFile."driftwm/config.toml".source =
        tomlFormat.generate "driftwm-config.toml" driftwmConfig;
      xdg.configFile."driftwm/background.glsl".source = ./_wallpaper.glsl;
      xdg.configFile."xdg-desktop-portal/driftwm-portals.conf".text = ''
        [preferred]
        default=kde
        org.freedesktop.impl.portal.ScreenCast=wlr
        org.freedesktop.impl.portal.Screenshot=wlr
      '';

      home.sessionVariables = {
        QT_QPA_PLATFORM = "wayland;xcb";
        QS_ICON_THEME = "breeze-dark";
      };
    };
  };
}
