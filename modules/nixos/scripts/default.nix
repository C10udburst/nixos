{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.scripts;
  gh-origin-mod = pkgs.writeShellScriptBin "gh-origin-mod" (builtins.readFile ./gh-origin-mod.sh);
  datauri = pkgs.writeShellScriptBin "datauri" (builtins.readFile ./datauri.sh);
  serial = pkgs.writeShellScriptBin "serial" (builtins.readFile ./serial.sh);
  www = pkgs.writeScriptBin "www" (builtins.readFile ./www.py);
  extract = pkgs.writeShellScriptBin "extract" (builtins.readFile ./extract.sh);
  nx = pkgs.writeShellScriptBin "nx" (builtins.readFile ./nx.sh);
  nix-py = pkgs.writeShellScriptBin "nix-py" (builtins.readFile ./nix-py.sh);

  noctalia-dmenu = pkgs.writeShellScriptBin "noctalia-dmenu" (builtins.readFile ./noctalia-dmenu.sh);
  rofi = pkgs.writeShellScriptBin "rofi" (builtins.readFile ./rofi.sh);

  palette = pkgs.writeShellScriptBin "palette" (builtins.readFile ./palette.sh);
  gcode-bounds = pkgs.writers.writePython3Bin "gcode-bounds" {} (builtins.readFile ./gcode-bounds.py);
  beamer-clean = pkgs.writers.writePython3Bin "beamer-clean" {
    libraries = with pkgs.python3Packages; [pypdf];
  } (builtins.readFile ./beamer-clean.py);
  sarif-md = pkgs.writers.writePython3Bin "sarif-md" {} (builtins.readFile ./sarif-md.py);
  ics-merge = pkgs.writers.writePython3Bin "ics-merge" {} (builtins.readFile ./ics-merge.py);
  video8mb = pkgs.writers.writePython3Bin "video8mb" {} (builtins.readFile ./video8mb.py);

  desktop-kickoff = pkgs.writeShellScriptBin "desktop-kickoff" (builtins.readFile ./desktop-kickoff.sh);
  desktop-kickoff-launcher = pkgs.makeDesktopItem {
    name = "desktop-kickoff";
    desktopName = "Cloudburst Desktop Kickoff";
    exec = "desktop-kickoff";
    icon = "kde";
    terminal = false;
  };
in {
  options.systemSettings.scripts = {
    enable = lib.mkEnableOption "Enable custom scripts module (including gh-origin-mod, datauri, serial, www, extract, gcode-bounds, beamer-clean, sarif-md, ics-merge, video8mb, nx, rofi, nix-py)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [
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
        noctalia-dmenu
        rofi
        palette
        nix-py
      ]
      ++ lib.optionals (config.networking.hostName != "cloudburst-desktop") [
        desktop-kickoff
        desktop-kickoff-launcher
      ];
  };
}
