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
    default = gamesEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.heroic];
  };
}
