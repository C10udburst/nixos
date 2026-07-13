{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.packages;
in {
  options.systemSettings.packages = {
    enable = lib.mkEnableOption "Enable standard system packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [
        eza
        alejandra
        qalculate-qt
        libargon2
        jq
        git
        nix-output-monitor
        nix-heuristic-gc
        polkit
        file
        curl
        wget
        openssh
        openssl
        tmux
        fastfetch
        libnotify
        gparted
        haruna
        ffmpeg
        yt-dlp
        wl-clipboard
        wlr-randr
        zip
        unzip
        unrar
        gnutar
        rar
        p7zip
        killall
        pciutils
        screen
        cabextract
        ncompress
        cpio
        socat
        libxcb-cursor
        hardinfo2
      ]
      ++ (
        if config.networking.wireless.enable
        then [wirelesstools]
        else []
      );

    hardware.bluetooth.enable = true;
  };
}
