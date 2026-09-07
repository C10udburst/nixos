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
  cfg = config.features.gui.dev.documents.latex;
in {
  options.features.gui.dev.documents.latex = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (devEnabled && cfg) {
    environment.systemPackages = with pkgs; [
      texlive.combined.scheme-medium
    ];
  };
}
