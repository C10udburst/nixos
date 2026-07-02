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
        alejandra
        jq
        git
        nix-output-monitor
        file
        curl
        wget
        openssh
        tmux
        fastfetch
        libnotify
        gparted
        haruna
        ffmpeg
        yt-dlp
        wl-clipboard
        zip
        unzip
        unrar
        gnutar
      ]
      ++ (
        if config.networking.wireless.enable
        then [wirelesstools]
        else []
      );

    hardware.bluetooth.enable = true;
  };
}
