{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.office.libreoffice;
  officeEnabled = config.features.gui.apps.editors.office.enable;
in {
  options.features.gui.apps.editors.office.libreoffice = lib.mkOption {
    type = lib.types.bool;
    default = officeEnabled && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.libreoffice-qt];
  };
}
