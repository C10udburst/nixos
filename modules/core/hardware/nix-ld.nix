{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
  isGui = config.features.gui.enable;

  coreLibraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib.out
    openssl
    dbus
    nss
    nspr
    alsa-lib
    libuuid
    udev
    expat
    libxml2
  ];

  guiLibraries = with pkgs; [
    libx11
    libxcursor
    libxrandr
    libxi
    libxext
    libxfixes
    libxtst
    libGL
    libxkbcommon
    fontconfig
    freetype
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    libdrm
    libxcb-cursor
    libxcomposite
    libxdamage
    libxrender
    libxxf86vm
    libpng
    vulkan-loader
  ];
in {
  options.features.core.hardware.nix-ld = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && true;
  };

  config = lib.mkIf cfg.nix-ld {
    services.envfs.enable = false;
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = coreLibraries ++ lib.optionals isGui guiLibraries;

    environment.sessionVariables = lib.mkIf isGui {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d";
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d";
    };
  };
}
