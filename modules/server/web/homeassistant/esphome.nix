{
  config,
  lib,
  pkgs,
  ...
}: let
  hassCfg = config.features.server.web.homeassistant;
  cfg = config.features.server.web.homeassistant.esphome;
  webHelper = import ../_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.homeassistant.esphome = lib.mkOption {
    type = lib.types.bool;
    default = hassCfg.enable && true;
  };

  config = lib.mkIf (hassCfg.enable && cfg) (lib.mkMerge [
    (webHelper.mkWebApp {
      name = "esphome";
      aliases = [ "esp" ];
      port = 6052;
      suspend = "esphome.service";
    })
    {
      services.esphome = {
        enable = true;
        port = 6052;
        address = "127.0.0.1";
      };
    }
  ]);
}
