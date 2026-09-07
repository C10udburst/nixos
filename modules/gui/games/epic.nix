{
  config,
  lib,
  pkgs,
  ...
}: let
  gamesEnabled = config.features.gui.enable && config.features.gui.games.enable;
  cfg = config.features.gui.games.epic;
in {
  options.features.gui.games.epic = lib.mkOption {
    type = lib.types.bool;
    default =
      if gamesEnabled
      then true
      else false;
  };

  config = lib.mkIf (gamesEnabled && cfg) {
    environment.systemPackages = [pkgs.heroic];
  };
}
