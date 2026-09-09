{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled = config.features.gui.dev.documents.enable;
  cfg = config.features.gui.dev.documents.latex;
in {
  options.features.gui.dev.documents.latex = lib.mkOption {
    type = lib.types.bool;
    default = devEnabled && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      texlive.combined.scheme-medium
    ];
  };
}
