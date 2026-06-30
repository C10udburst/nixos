{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.threed;

  # Common libraries needed by graphical AppImages (Qt/GTK) on NixOS
  appimageLibs = pkgs:
    with pkgs; [
      qt5.qtbase
      libxcb
      libxkbfile
      libxkbcommon
      libx11
      libxcursor
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxcb-wm
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libGL
      libGLU
      dbus
      fontconfig
      freetype
      glib
      gtk3
      pango
      cairo
      atk
      gdk-pixbuf
      libsecret
      libunwind
      libusb1
      libglvnd
    ];

  orcaslicer-nanashi = let
    pname = "orcaslicer-nanashi";
    version = "nightly";
    src = pkgs.fetchurl {
      url = "https://github.com/NanashiTheNameless/OrcaSlicer/releases/download/Nightly-Rolling/OrcaSlicer_Linux_AppImage_Ubuntu2404_nightly.AppImage";
      sha256 = "75f3d10504f97a0835796994a8676d983e83824655d781e57cc359bcd2965ac2";
    };
    appimageContents = pkgs.appimageTools.extractType2 {
      inherit pname version src;
    };
    desktopItem = pkgs.makeDesktopItem {
      name = "orcaslicer-nanashi";
      exec = "orcaslicer-nanashi";
      icon = "orcaslicer-nanashi";
      comment = "3D Slicer for 3D Printers";
      desktopName = "OrcaSlicer (Nanashi)";
      genericName = "3D Slicer";
      categories = ["Utility" "3DGraphics"];
    };
  in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      extraPkgs = pkgs: (appimageLibs pkgs) ++ [pkgs.webkitgtk_4_1];
      extraInstallCommands = ''
        # Copy desktop file
        mkdir -p $out/share/applications
        cp ${desktopItem}/share/applications/* $out/share/applications/

        # Copy icon
        mkdir -p $out/share/icons/hicolor/128x128/apps
        find ${appimageContents} -maxdepth 1 -name "*.png" -exec cp {} $out/share/icons/hicolor/128x128/apps/orcaslicer-nanashi.png \;
      '';
    };

  dust3d = let
    pname = "dust3d";
    version = "1.1.6";
    src = pkgs.fetchurl {
      url = "https://github.com/huxingyi/dust3d/releases/download/1.1.6/dust3d-1.1.6.AppImage";
      sha256 = "efbc1fafe9aa6cbc2679494e45a43bae6df50c7feec58e4a850e94189904fc5a";
    };
    appimageContents = pkgs.appimageTools.extractType2 {
      inherit pname version src;
    };
    desktopItem = pkgs.makeDesktopItem {
      name = "dust3d";
      exec = "dust3d";
      icon = "dust3d";
      comment = "3D Modeling Software";
      desktopName = "Dust3D";
      genericName = "3D Modeling";
      categories = ["Utility" "3DGraphics"];
    };
  in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      extraPkgs = appimageLibs;
      extraInstallCommands = ''
        # Copy desktop file
        mkdir -p $out/share/applications
        cp ${desktopItem}/share/applications/* $out/share/applications/

        # Copy icon
        mkdir -p $out/share/icons/hicolor/128x128/apps
        find ${appimageContents} -maxdepth 1 -name "*.png" -exec cp {} $out/share/icons/hicolor/128x128/apps/dust3d.png \;
      '';
    };
in {
  options.systemSettings.threed = {
    enable = lib.mkEnableOption "Enable 3D modeling and slicing tools (Blender, custom OrcaSlicer, and Dust3D)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      blender
      orcaslicer-nanashi
      dust3d
      openscad
    ];
  };
}
