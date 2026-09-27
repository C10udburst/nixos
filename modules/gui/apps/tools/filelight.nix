{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.filelight;
  toolsEnabled = config.features.gui.apps.tools.enable;
in {
  options.features.gui.apps.tools.filelight = lib.mkOption {
    type = lib.types.bool;
    default = toolsEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.kdePackages.filelight];
  };
}
