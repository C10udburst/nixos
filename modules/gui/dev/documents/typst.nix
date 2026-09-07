{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled =
    config.features.gui.enable
    && config.features.gui.dev.enable
    && config.features.gui.dev.documents.enable;
  cfg = config.features.gui.dev.documents.typst;
in {
  options.features.gui.dev.documents.typst = lib.mkOption {
    type = lib.types.bool;
    default = devEnabled && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      typst
      typstyle
    ];
  };
}
