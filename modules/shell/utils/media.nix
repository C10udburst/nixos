{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.media;
in {
  options.features.shell.utils.media = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.shell.enable && config.features.shell.utils.enable) && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      ffmpeg
      qrencode
      zbar
      yt-dlp
    ];
  };
}
