{
  config,
  lib,
  ...
}: let
  gamesEnabled = config.features.gui.enable && config.features.gui.games.enable;
  cfg = config.features.gui.games.steam;
in {
  options.features.gui.games.steam = lib.mkOption {
    type = lib.types.bool;
    default =
      if gamesEnabled
      then true
      else false;
  };

  config = lib.mkIf (gamesEnabled && cfg) {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.gamemode.enable = true;
  };
}
