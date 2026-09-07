{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.archive;
  utilsEnabled = config.features.shell.enable && config.features.shell.utils.enable;
in {
  options.features.shell.utils.archive = lib.mkOption {
    type = lib.types.bool;
    default =
      if utilsEnabled
      then true
      else false;
  };

  config = lib.mkIf (utilsEnabled && cfg) {
    environment.systemPackages = with pkgs; [
      zip
      unzip
      unrar
      rar
      p7zip
      gnutar
      cabextract
      ncompress
      cpio
    ];
  };
}
