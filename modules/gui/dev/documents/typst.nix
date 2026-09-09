{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled = config.features.gui.dev.documents.enable;
  cfg = config.features.gui.dev.documents.typst;
in {
  options.features.gui.dev.documents.typst = lib.mkOption {
    type = lib.types.bool;
    default = devEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      typst
      typstyle
    ];
  };
}
