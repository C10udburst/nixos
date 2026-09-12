{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.wealthfolio;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.wealthfolio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (webHelper.mkWebApp {
      name = "wealth";
      aliases = [ "wealthfolio" ];
      port = 8088;
      suspend = "podman-wealthfolio.service";
    })
    {
      systemd.tmpfiles.rules = [
        "d ${storage}/wealthfolio 0755 root root -"
      ];

      virtualisation.oci-containers.containers.wealthfolio = {
        image = "wealthfolio/wealthfolio:latest";
        ports = [
          "127.0.0.1:8088:8088"
        ];
        volumes = [
          "${storage}/wealthfolio:/data"
        ];
        environment = {
          WF_LISTEN_ADDR = "0.0.0.0:8088";
          WF_DB_PATH = "/data/wealthfolio.db";
        };
      };
    }
  ]);
}
