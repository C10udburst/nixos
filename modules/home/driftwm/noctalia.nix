{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  mobile = config.hostSettings.mobile or false;

  pluginMap = {
    audio-switcher = "blackbartblues/audio-switcher";
    battery-threshold = "damian-ds7/battery-threshold";
    eyecare = "apex077/eyecare";
    hassio = "pozzoo/hassio";
    lid-guard = "8bury/lid-guard";
    nix-monitor = "avivbintangaringga/nix-monitor";
    phone-connect = "icefish/phone-connect";
    screen-toolkit = "alexander/screen-toolkit";
    tailscale = "davemhammer/tailscale";
    udiskie = "aristides/udiskie";
    web-launcher = "yocraft/web-launcher";
  };

  basePluginNames = [
    "audio-switcher"
    "eyecare"
    "hassio"
    "nix-monitor"
    "phone-connect"
    "screen-toolkit"
    "tailscale"
    "udiskie"
    "web-launcher"
  ];

  batteryPluginNames = optionals mobile [
    "battery-threshold"
    "lid-guard"
  ];

  selectedPluginNames = basePluginNames ++ batteryPluginNames;

  enabledPluginIds = map (name: pluginMap.${name}) selectedPluginNames;
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = {
    programs.noctalia = {
      enable = true;
      settings = {
        shell = {
          font_family = config.stylix.fonts.monospace.name or "monospace";
          polkit_agent = true;
          password_style = "random";
        };
        wallpaper.enabled = false;
        weather.enabled = true;
        location.auto_locate = true;
        widget = {
          driftwm = {
            type = "custom_button";
            glyph = "zoom-scan";
            scroll_repeat = "steps";
            action = {
              scroll_up = "driftwm msg action zoom-in";
              scroll_down = "driftwm msg action zoom-out";
              left = "driftwm msg action zoom-to-fit";
              middle = "driftwm msg action home-toggle";
              right = "driftwm msg action zoom-reset";
            };
          };
          battery = {
            display_mode = "graphic";
          };
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
        };
        idle.behavior.screen-off.enabled = true;
        idle.behavior.lock.enabled = mobile;
        idle.behavior.suspend.enabled = mobile;
        audio = {
          enable_overdrive = true;
          enable_sounds = true;
        };
        brightness = {
          enable_ddcutil = true;
          sync_all_monitors = true;
          minimum_brightness = 0.1;
        };
        bar = {
          order = ["main"];
          main = {
            start = [
              "launcher"
              "clock"
              "sysmon"
              "media"
              "audio_visualizer"
            ];
            center = [
              "driftwm"
              "active_window"
              "clipboard"
              "notifications"
            ];
            end =
              [
                "tray"
                "privacy"
              ]
              ++ optionals mobile [
                "battery"
                "caffeine"
              ]
              ++ optionals (config.hostSettings.tailscale or false) [
                (pluginMap.tailscale + ":status")
              ]
              ++ [
                "brightness"
                "volume"
                "bluetooth"
                "control-center"
              ];
          };
        };
        plugins = {
          enabled = enabledPluginIds;
          source = [
            {
              name = "community";
              kind = "path";
              location = "${inputs.noctalia-community-plugins}";
            }
          ];
        };
      };
    };
  };
}
