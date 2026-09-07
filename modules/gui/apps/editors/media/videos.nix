{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.media.videos;
  editorsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable;
in {
  options.features.gui.apps.editors.media.videos = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.apps.editors.media.enable && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      kdePackages.kdenlive
    ];
  };
}
