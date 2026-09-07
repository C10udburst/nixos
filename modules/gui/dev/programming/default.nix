{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  devEnabled = config.features.gui.enable && config.features.gui.dev.enable;
  cfg = config.features.gui.dev.programming;

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
  options.features.gui.dev.programming = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf (devEnabled && cfg.enable) {
    environment.systemPackages = with pkgs; [
      sqlitebrowser
      imhex
      gdb
      gcc
      gitr
    ];

    boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
  };
}
