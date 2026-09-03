{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.scripts;
  beamer-clean = pkgs.writers.writePython3Bin "beamer-clean" {libraries = with pkgs.python3Packages; [pypdf];} (builtins.readFile ./beamer-clean.py);
  datauri = pkgs.writeShellScriptBin "datauri" (builtins.readFile ./datauri.sh);
  extract = pkgs.writeShellScriptBin "extract" (builtins.readFile ./extract.sh);
  gcode-bounds = pkgs.writers.writePython3Bin "gcode-bounds" {} (builtins.readFile ./gcode-bounds.py);
  gh-origin-mod = pkgs.writeShellScriptBin "gh-origin-mod" (builtins.readFile ./gh-origin-mod.sh);
  ics-merge = pkgs.writers.writePython3Bin "ics-merge" {} (builtins.readFile ./ics-merge.py);
  nix-py = pkgs.writeShellScriptBin "nix-py" (builtins.readFile ./nix-py.sh);
  nx = pkgs.writeShellScriptBin "nx" (builtins.readFile ./nx.sh);
  palette = pkgs.writeShellScriptBin "palette" (builtins.readFile ./palette.sh);
  rofi = pkgs.writeShellScriptBin "rofi" (builtins.readFile ./rofi.sh);
  sarif-md = pkgs.writers.writePython3Bin "sarif-md" {} (builtins.readFile ./sarif-md.py);
  serial = pkgs.writeShellScriptBin "serial" (builtins.readFile ./serial.sh);
  video8mb = pkgs.writers.writePython3Bin "video8mb" {} (builtins.readFile ./video8mb.py);
  www = pkgs.writeScriptBin "www" (builtins.readFile ./www.py);
  icat = pkgs.writeShellScriptBin "icat" (builtins.readFile ./icat.sh);

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
    text = builtins.readFile ./auto-rotate.sh;
  };

  desktop-kickoff = pkgs.writeShellScriptBin "desktop-kickoff" (builtins.readFile ./desktop-kickoff.sh);
  desktop-kickoff-launcher = pkgs.makeDesktopItem {
    name = "desktop-kickoff";
    desktopName = "Desktop Kickoff";
    exec = "desktop-kickoff";
    icon = "kde";
    terminal = false;
  };
in {
  options.systemSettings.scripts = {
    enable = lib.mkEnableOption "Enable custom scripts module";
  };

  config = {
    environment.systemPackages =
      lib.optionals (config.systemSettings.touchscreen.enable or false) [
        auto-rotate
      ]
      ++ lib.optionals cfg.enable [
        gh-origin-mod
        datauri
        serial
        www
        extract
        gcode-bounds
        beamer-clean
        sarif-md
        ics-merge
        video8mb
        nx
        rofi
        palette
        nix-py
        icat
        pkgs.chafa
        pkgs.libsixel
      ]
      ++ lib.optionals (config.networking.hostName != "cloudburst-desktop") [
        desktop-kickoff
        desktop-kickoff-launcher
      ];
  };
}
