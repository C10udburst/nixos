{
  config,
  lib,
  pkgs,
  ...
}: let
  hassCfg = config.features.server.web.homeassistant;
  cfg = config.features.server.web.homeassistant.esphome;
  storage = config.features.server.web.storage;
  esphomeDir = "${storage}/homeassistant/esphome";
  webHelper = import ../_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.homeassistant.esphome = lib.mkOption {
    type = lib.types.bool;
    default = hassCfg.enable && true;
  };

  config = lib.mkIf (hassCfg.enable && cfg) (lib.mkMerge [
    (webHelper.mkWebApp {
      name = "esphome";
      aliases = ["esp"];
      port = 6052;
      suspend = "esphome.service";
    })
    {
      systemd.tmpfiles.rules = [
        "d ${esphomeDir} 0750 esphome esphome - -"
      ];

      systemd.services.esphome.serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.esphome}/bin/esphome dashboard --address 127.0.0.1 --port 6052 ${esphomeDir}";
        WorkingDirectory = lib.mkForce esphomeDir;
        ReadWritePaths = [esphomeDir];
        ExecPaths = [esphomeDir];
      };

      services.esphome = {
        enable = true;
        port = 6052;
        address = "127.0.0.1";
        usePing = true;
      };

      networking.firewall.allowedUDPPorts = [5353];
    }
  ]);
}
