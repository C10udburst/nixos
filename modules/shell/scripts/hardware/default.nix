{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.scripts.hardware;
  serial = pkgs.writeShellScriptBin "serial" (builtins.readFile ./_serial.sh);
  extract = pkgs.writeShellScriptBin "extract" (builtins.readFile ./_extract.sh);
  www = pkgs.writeScriptBin "www" (builtins.readFile ./_www.py);
  rofi = pkgs.writeShellScriptBin "rofi" (builtins.readFile ./_rofi.sh);
  auto-rotate = pkgs.writeShellApplication {
    name = "auto-rotate";
    runtimeInputs = [
      pkgs.wlr-randr
      pkgs.iio-sensor-proxy
      pkgs.gnugrep
      pkgs.gawk
      pkgs.systemd
      pkgs.coreutils
    ];
    text = builtins.readFile ./_auto-rotate.sh;
  };
  desktop-kickoff = pkgs.writeShellScriptBin "desktop-kickoff" (builtins.readFile ./_desktop-kickoff.sh);
  desktop-kickoff-launcher = pkgs.makeDesktopItem {
    name = "desktop-kickoff";
    desktopName = "Desktop Kickoff";
    exec = "desktop-kickoff";
    icon = "kde";
    terminal = false;
  };
  weylus-screen = pkgs.writeShellApplication {
    name = "weylus-screen";
    runtimeInputs = [
      pkgs.wlr-randr
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.coreutils
      pkgs.systemd
    ];
    text = builtins.readFile ./_weylus-screen.sh;
  };
in {
  options.features.shell.scripts.hardware = lib.mkOption {
    type = lib.types.bool;
    default =
      if (config.features.shell.enable && config.features.shell.scripts.enable)
      then true
      else false;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        isw = {
          url = "github:YoyPa/isw";
          flake = false;
        };
      };
    }
    (lib.mkIf (config.features.shell.enable && config.features.shell.scripts.enable && cfg) {
      environment.systemPackages =
        [
          serial
          extract
          www
          rofi
        ]
        ++ lib.optionals (config.features.core.hardware.touchscreen or false) [
          auto-rotate
        ]
        ++ lib.optionals (config.features.services.weylus or false) [
          weylus-screen
        ]
        ++ lib.optionals (config.networking.hostName != "cloudburst-desktop") [
          desktop-kickoff
          desktop-kickoff-launcher
        ];
    })
  ];
}
