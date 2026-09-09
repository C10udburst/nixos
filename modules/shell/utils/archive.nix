{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.archive;
  utilsEnabled = config.features.shell.utils.enable;
in {
  options.features.shell.utils.archive = lib.mkOption {
    type = lib.types.bool;
    default = utilsEnabled && true;
  };

  config = lib.mkIf cfg {
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
