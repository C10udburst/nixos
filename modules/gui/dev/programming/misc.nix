{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  devEnabled = config.features.gui.dev.programming.enable;
  cfg = config.features.gui.dev.programming.misc;

  gitr = pkgs.appimageTools.wrapType2 {
    pname = "gitr";
    version = "v0.4.17";
    src = inputs.gitr;
    extraPkgs = pkgs':
      with pkgs'; [
        gtk3
        openssl
        libxkbcommon
        fontconfig
        libxcb
        fuse
      ];
  };
in {
  options.features.gui.dev.programming.misc = lib.mkOption {
    type = lib.types.bool;
    default = devEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        gitr = {
          url = "https://github.com/islandspan-solutions/gitr/releases/latest/download/gitr-x86_64.AppImage";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = [
        pkgs.sqlitebrowser
        gitr
        pkgs.gdb
        pkgs.imhex
      ];
    })
  ];
}
