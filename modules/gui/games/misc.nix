{
  config,
  lib,
  pkgs,
  ...
}: let
  gamesEnabled = config.features.gui.enable && config.features.gui.games.enable;
  cfg = config.features.gui.games.misc;
in {
  options.features.gui.games.misc = lib.mkOption {
    type = lib.types.bool;
    default =
      if gamesEnabled
      then true
      else false;
  };

  config = lib.mkIf (gamesEnabled && cfg) {
    environment.systemPackages = with pkgs; [
      protonup-qt
      lutris
      mangohud
    ];
  };
}
