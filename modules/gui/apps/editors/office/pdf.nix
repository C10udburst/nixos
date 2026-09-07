{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.office.pdf;
  officeEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable
    && config.features.gui.apps.editors.office.enable;
in {
  options.features.gui.apps.editors.office.pdf = lib.mkOption {
    type = lib.types.bool;
    default = officeEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      karp
      poppler-utils
      pandoc
      pdfgrep
    ];
  };
}
