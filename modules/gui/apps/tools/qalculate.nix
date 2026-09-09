{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.qalculate;
in {
  options.features.gui.apps.tools.qalculate = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.apps.tools.enable && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.qalculate-qt];
  };
}
