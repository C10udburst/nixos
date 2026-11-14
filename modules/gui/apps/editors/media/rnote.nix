{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.media.rnote;
in {
  options.features.gui.apps.editors.media.rnote = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.apps.editors.media.enable && false;
  };

  config = (
    lib.mkIf cfg {
      environment.systemPackages = [pkgs.rnote];
    }
  );
}
