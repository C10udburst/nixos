{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.scripts.hardware;
  isGui = config.features.gui.enable or false;
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
      pkgs.gnused
      pkgs.gawk
      pkgs.coreutils
    ];
    text = builtins.readFile ./_weylus-screen.sh;
  };
in {
  options.features.shell.scripts.hardware = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.scripts.enable && true;
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
    (lib.mkIf cfg {
      environment.systemPackages =
        [
          serial
          extract
          www
        ]
        ++ lib.optionals isGui [
          rofi
        ]
        ++ lib.optionals (isGui && (config.features.core.hardware.touchscreen or false)) [
          auto-rotate
        ]
        ++ lib.optionals (isGui && (config.features.services.weylus or false)) [
          weylus-screen
        ]
        ++ lib.optionals (isGui && (config.networking.hostName != "cloudburst-desktop")) [
          desktop-kickoff
          desktop-kickoff-launcher
        ];
    })
  ];
}
