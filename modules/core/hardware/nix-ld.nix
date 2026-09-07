{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.nix-ld = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.core.enable && config.features.core.hardware.enable) && true;
  };

  config = lib.mkIf cfg.nix-ld {
    services.envfs.enable = false;
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glib.out
      openssl
      libx11
      libxcursor
      libxrandr
      libxi
      libxext
      libxfixes
      libxtst
      libGL
      libxkbcommon
      dbus
      fontconfig
      freetype
      gtk3
      pango
      cairo
      gdk-pixbuf
      atk
      nss
      nspr
      alsa-lib
      libuuid
      libdrm
      udev
      libxcb-cursor
      libxcomposite
      libxdamage
      libxrender
      libxxf86vm
      expat
      libxml2
      libpng
      vulkan-loader
    ];

    environment.sessionVariables = {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d";
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d";
    };
  };
}
