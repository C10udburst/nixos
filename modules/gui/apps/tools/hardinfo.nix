{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.hardinfo;
  toolsEnabled = config.features.gui.apps.tools.enable;
in {
  options.features.gui.apps.tools.hardinfo = lib.mkOption {
    type = lib.types.bool;
    default = toolsEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.hardinfo2];
  };
}
