{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  mobile = config.hostSettings.mobile or false;
  touchscreen = config.hostSettings.touchscreen or false;
  slow = config.hostSettings.slow or false;
  compactMode = mobile && touchscreen;
  hasDocker = config.hostSettings.podman or false;
  hasTailscale = config.hostSettings.tailscale or false;
  colors = config.lib.stylix.colors.withHashtag;
  stylixColors = config.lib.stylix.colors;
  wvkbdCmd = "${pkgs.wvkbd}/bin/wvkbd-mobintl -L 280 -H 300 -R 16 -l fullwide --landscape-layers fullwide --bg ${stylixColors.base00} --fg ${stylixColors.base01} --fg-sp ${stylixColors.base02} --press ${stylixColors.base0D} --press-sp ${stylixColors.base0E} --text ${stylixColors.base05} --text-sp ${stylixColors.base07}";

  pluginMap = {
    audio-switcher = "blackbartblues/audio-switcher";
    battery-threshold = "damian-ds7/battery-threshold";
    cat = "dotnetrob/cat";
    driftwm = "cloudburst/driftwm";
    drive-health = "gustav0ar/drive-health";
    hassio = "pozzoo/hassio";
    lid-guard = "8bury/lid-guard";
    mini-docker = "8bury/mini-docker";
    nix-monitor = "avivbintangaringga/nix-monitor";
    phone-connect = "icefish/phone-connect";
    portctl = "rxtsel/portctl";
    procmon = "weinguyen/procmon";
    screen-toolkit = "alexander/screen-toolkit";
    tailscale = "davemhammer/tailscale";
    udiskie = "aristides/udiskie";
    web-launcher = "yocraft/web-launcher";
  };

  disabledSlowPlugins = [
    "udiskie"
    "procmon"
    "portctl"
    "drive-health"
    "nix-monitor"
    "screen-toolkit"
    "lid-guard"
  ];

  rawBasePluginNames = [
    "audio-switcher"
    "cat"
    "driftwm"
    "drive-health"
    "hassio"
    "nix-monitor"
    "phone-connect"
    "portctl"
    "procmon"
    "screen-toolkit"
    "udiskie"
    "web-launcher"
  ];

  basePluginNames = filter (name: !(slow && elem name disabledSlowPlugins)) rawBasePluginNames;

  batteryPluginNames = optionals mobile [
    "battery-threshold"
    "lid-guard"
  ];

  dockerPluginNames = optionals (hasDocker && !slow) ["mini-docker"];
  tailscalePluginNames = optionals hasTailscale ["tailscale"];

  selectedPluginNames =
    basePluginNames ++ batteryPluginNames ++ dockerPluginNames ++ tailscalePluginNames;
  enabledPluginIds = map (name: pluginMap.${name}) selectedPluginNames;

  wvkbdPackage = pkgs.writeShellScriptBin "wvkbd" ''
    ${wvkbdCmd} "$@"
  '';
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = {
    home.packages = with pkgs;
      [
        ddcutil
        wl-screenrec
      ]
      ++ (optionals touchscreen [wvkbdPackage])
      ++ (optionals mobile [
        upower
      ])
      ++ (optionals (!slow) [
        tesseract
        udiskie
        smartmontools
      ]);

    xdg.configFile."noctalia/palettes/Stylix.json".text = builtins.toJSON {
      dark = {
        mPrimary = colors.base0D;
        mOnPrimary = colors.base00;
        mSecondary = colors.base0E;
        mOnSecondary = colors.base00;
        mTertiary = colors.base0C;
        mOnTertiary = colors.base00;
        mError = colors.base08;
        mOnError = colors.base00;
        mSurface = colors.base00;
        mOnSurface = colors.base05;
        mSurfaceVariant = colors.base01;
        mOnSurfaceVariant = colors.base05;
        mOutline = colors.base03;
        mShadow = colors.base00;
        mHover = colors.base02;
        mOnHover = colors.base05;

        terminal = {
          background = colors.base00;
          foreground = colors.base05;
          cursor = colors.base05;
          cursorText = colors.base00;
          selectionBg = colors.base02;
          selectionFg = colors.base05;
          normal = {
            black = colors.base00;
            red = colors.base08;
            green = colors.base0B;
            yellow = colors.base0A;
            blue = colors.base0D;
            magenta = colors.base0E;
            cyan = colors.base0C;
            white = colors.base05;
          };
          bright = {
            black = colors.base03;
            red = colors.base08;
            green = colors.base0B;
            yellow = colors.base0A;
            blue = colors.base0D;
            magenta = colors.base0E;
            cyan = colors.base0C;
            white = colors.base07;
          };
        };
      };
    };

    programs.noctalia = {
      enable = true;
      settings = {
        shell = {
          setup_wizard_enabled = false;
          corner_radius_scale = 2.0;
          font_family = config.stylix.fonts.monospace.name or "monospace";
          polkit_agent = true;
          password_style = "random";
          panel_anchor_bar = "main";
          screen_time_enabled = true;
          settings_window_translucent = true;
          launcher.providers.windows.global = true;
          panel = {
            session_position = "center";
            transparency_mode = "solid";
            control_center_placement = "floating";
            open_near_click_control_center = true;
            session_placement = "floating";
            floating_offset = 16;
          };
          session.actions = [
            {
              action = "lock";
              shortcut = "1";
            }
            {
              action = "logout";
              command = "driftwm msg action quit";
              shortcut = "2";
            }
            {
              action = "lock_and_suspend";
              shortcut = "3";
            }
            {
              action = "reboot";
              shortcut = "4";
            }
            {
              action = "shutdown";
              shortcut = "5";
              variant = "destructive";
            }
          ];
        };

        wallpaper.enabled = false;
        weather.enabled = true;
        location.auto_locate = true;
        desktop_widgets.enabled = false;
        nightlight.enabled = true;

        theme = {
          mode = config.stylix.polarity or "dark";
          source = "custom";
          custom_palette = "Stylix";
          pure_black_dark = false;
          templates = {
            enable_builtin_templates = false;
            enable_community_templates = false;
          };
        };

        lockscreen = {
          blurred_desktop = true;
          allow_empty_password = false;
        };

        dock = {
          auto_hide = false;
          cross_axis_padding = 4;
          main_axis_padding = 4;
          item_spacing = 4;
          background_opacity = 0.5;
          enabled = true;
          icon_size = 28;
          launcher_position = "start";
          show_dots = true;
        };

        idle = {
          behavior_order =
            if mobile
            then [
              "lock"
              "screen-off"
              "suspend"
            ]
            else ["screen-off"];
          behavior = {
            screen-off.enabled = true;
            lock.enabled = mobile;
            suspend.enabled = mobile;
          };
        };

        audio = {
          enable_overdrive = true;
          enable_sounds = true;
          sound_volume = 0.75;
        };

        brightness = {
          enable_ddcutil = true;
          sync_all_monitors = true;
          minimum_brightness = 0.1;
        };

        calendar = {
          enabled = true;
          account = {
            polish_holiday = {
              name = "Święta w Polsce";
              server_url = "https://calendar.google.com/calendar/ical/pl.polish%23holiday%40group.v.calendar.google.com/public/basic.ics";
              type = "ics";
            };
          };
        };

        control_center = {
          sidebar = "full";
          calendar.show_week_numbers = true;
          shortcuts = [
            {type = "wifi";}
            {type = "bluetooth";}
            {type = "caffeine";}
            {type = "nightlight";}
            {type = "mic_mute";}
            {type = "notification";}
          ];
        };

        bar = {
          order = ["main"];
          main = {
            radius = 24;
            background_opacity = 0.75;
            margin_ends =
              if compactMode
              then 10
              else 100;
            reserve_space = false;
            thickness = 36;
            scale =
              if compactMode
              then 1.5
              else 1.0;
            compact = compactMode;

            start =
              [
                "launcher"
                "clock"
              ]
              ++ optionals (!compactMode) ["weather"]
              ++ optionals (!slow) ["group:sysmon_group"]
              ++ optionals (!compactMode) ["group:media_group"]
              ++ [
                "hassio_status"
              ];
            center =
              if compactMode
              then
                [
                  "driftwm"
                ]
                ++ optionals (!slow) ["screen_toolkit"]
                ++ [
                  "session"
                ]
                ++ optionals touchscreen ["wvkbd_toggle"]
                ++ [
                  "clipboard"
                  "group:notifications_group"
                ]
              else
                [
                  "group:window_session"
                ]
                ++ optionals touchscreen ["wvkbd_toggle"]
                ++ [
                  "lock_keys"
                  "active_window"
                  "clipboard"
                  "group:notifications_group"
                ];
            end =
              [
                "tray"
              ]
              ++ optionals (!compactMode) ["group:storage_privacy"]
              ++ optionals mobile ["group:battery_group"]
              ++ [
                "group:network_group"
                "group:system_controls"
                "control-center"
              ];

            capsule_group =
              [
                {
                  id = "system_controls";
                  accordion = false;
                  accordion_direction = "end";
                  enabled = true;
                  members = [
                    "brightness"
                    "volume"
                    "bluetooth"
                  ];
                }
                {
                  id = "network_group";
                  accordion = true;
                  accordion_direction = "end";
                  enabled = true;
                  members =
                    [
                      "network"
                    ]
                    ++ (optionals hasTailscale ["tailscale_status"]);
                }
                {
                  id = "storage_privacy";
                  accordion = true;
                  accordion_direction = "end";
                  enabled = true;
                  members =
                    [
                      "privacy"
                    ]
                    ++ (optionals (!slow) [
                      "udiskie_status"
                      "drive_summary"
                    ]);
                }
                {
                  id = "window_session";
                  accordion = true;
                  accordion_direction = "end";
                  enabled = true;
                  members =
                    [
                      "driftwm"
                    ]
                    ++ (optionals (!slow) ["screen_toolkit"])
                    ++ [
                      "session"
                    ];
                }
                {
                  id = "media_group";
                  accordion = true;
                  accordion_direction = "end";
                  enabled = true;
                  members =
                    (optionals (!slow) ["audio_visualizer"])
                    ++ [
                      "media"
                    ];
                }
                {
                  id = "notifications_group";
                  accordion = true;
                  accordion_direction = "start";
                  enabled = true;
                  members =
                    [
                      "notifications"
                    ]
                    ++ (optionals (!slow) ["nix-monitor"])
                    ++ [
                      "phone_bar"
                    ];
                }
                {
                  id = "sysmon_group";
                  accordion = true;
                  accordion_direction = "end";
                  enabled = !slow;
                  members =
                    [
                      "cat_widget"
                    ]
                    ++ (optionals (!slow) [
                      "procmon_widget"
                      "portctl_indicator"
                    ])
                    ++ optionals (hasDocker && !slow) ["mini-docker"];
                }
              ]
              ++ optionals mobile [
                {
                  id = "battery_group";
                  accordion = true;
                  accordion_direction = "end";
                  enabled = true;
                  members = [
                    "battery"
                    "battery-threshold"
                  ];
                }
              ];
          };
        };

        notification = {
          history_retention_hours = 64;
        };

        plugins = {
          enabled = enabledPluginIds;
          source = [
            {
              name = "community";
              kind = "path";
              location = "${inputs.noctalia-community-plugins}";
            }
            {
              name = "driftwm";
              kind = "path";
              location = "${inputs.noctalia-driftwm}";
            }
          ];
        };

        plugin_settings = with pluginMap;
          {
            "${screen-toolkit}" = {
              panel_placement = "attached";
              result_placement = "attached";
              selected-ocr-lang = "eng+pl";
            };
            "${udiskie}" = {
              manager_open_near_click = true;
              file_manager_cmd = "dolphin";
            };
            "${nix-monitor}" = {
              branch = "nixos-${lib.trivial.release}";
              show_update_available_notification = false;
              update_command = "~/nixos/upgrade";
            };
            "${drive-health}".drives_placement = "attached";
            "${phone-connect}".details_placement = "floating";
            "${hassio}" = {
              entity_manager_open_near_click = true;
              entity_manager_placement = "attached";
            };
            "${procmon}".panel_placement = "attached";
            "${web-launcher}".notify = false;
          }
          // optionalAttrs mobile {
            "${battery-threshold}".panel_placement = "attached";
          }
          // optionalAttrs hasDocker {
            "${mini-docker}".manager_placement = "attached";
          }
          // optionalAttrs hasTailscale {
            "${tailscale}".manager_placement = "attached";
          };

        widget = with pluginMap;
          {
            audio_visualizer.mirrored = false;
            clock = {
              format =
                if compactMode
                then "{:%H:%M:%S %d.%m}"
                else "{:%H:%M:%S %a, %d.%m}";
              vertical_format = "{:%H:%M}";
            };
            network = {
              show_label = !compactMode;
            };
            driftwm = {
              type = "${driftwm}:widget";
            };
            lock_keys = {
              hide_when_off = true;
              show_scroll_lock = true;
            };
            media = {
              hide_when_no_media = true;
              title_scroll = "on_hover";
            };
            weather.show_condition = false;

            # Renamed plugin widgets
            phone_bar.type = "${phone-connect}:bar";
            cat_widget = {
              show_cpu_percent = true;
              type = "${cat}:cat";
              actions = {
                middle = "exec plasma-systemmonitor";
                right = "panel-toggle control-center system";
              };
            };
            portctl_indicator.type = "${portctl}:indicator";
            nix-monitor = {
              show_text = false;
              type = "${nix-monitor}:nix-monitor";
            };
            udiskie_status.type = "${udiskie}:status";
            hassio_status.type = "${hassio}:status";
            drive_summary.type = "${drive-health}:summary";
            screen_toolkit.type = "${screen-toolkit}:widget";
            procmon_widget.type = "${procmon}:widget";
          }
          // optionalAttrs mobile {
            battery.display_mode = "graphic";
            battery-threshold.type = "${battery-threshold}:battery-threshold";
          }
          // optionalAttrs hasDocker {
            mini-docker.type = "${mini-docker}:mini-docker";
          }
          // optionalAttrs hasTailscale {
            tailscale_status.type = "${tailscale}:status";
          }
          // optionalAttrs touchscreen {
            wvkbd_toggle = {
              type = "custom_button";
              glyph = "keyboard";
              tooltip = "On-Screen Keyboard";
              actions = {
                left = "exec pkill wvkbd-mobintl || wvkbd";
              };
            };
          };
      };
    };
  };
}
