{
  config,
  lib,
  pkgs,
  ...
}:
let
  gamesEnabled = config.features.gui.games.enable;
  cfg = config.features.gui.games.misc;
in
{
  options.features.gui.games.misc = lib.mkOption {
    type = lib.types.bool;
    default = gamesEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      mangohud
    ];
  };
}
