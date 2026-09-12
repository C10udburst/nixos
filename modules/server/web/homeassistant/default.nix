{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.homeassistant;
  storage = config.features.server.web.storage;
  webHelper = import ../_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.homeassistant = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (webHelper.mkWebApp {
      name = "hass";
      aliases = ["home-assistant"];
      port = 8123;
    })
    {
      services.home-assistant = {
        enable = true;
        configDir = "${storage}/homeassistant";
        config = {
          http = {
            use_x_forwarded_for = true;
            trusted_proxies = [
              "127.0.0.1"
              "::1"
            ];
          };
        };
      };
    }
  ]);
}
