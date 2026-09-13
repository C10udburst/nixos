{
  config,
  lib,
  pkgs,
  helpers,
  ...
}:
let
  cfg = config.features.server.web.wealthfolio;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.wealthfolio = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "wealth";
        aliases = [ "wealthfolio" ];
        port = 8088;
        suspend = "podman-wealthfolio.service";
      })
      {
        users.users.wealthfolio = {
          isSystemUser = true;
          group = "wealthfolio";
          home = "${storage}/wealthfolio";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.wealthfolio = { };

        systemd.tmpfiles.rules = [
          "d ${storage}/wealthfolio 0750 wealthfolio wealthfolio - -"
        ];

        virtualisation.oci-containers.containers.wealthfolio = {
          image = helpers.resolveImage "ghcr.io/wealthfolio/wealthfolio:latest";
          podman.user = "wealthfolio";
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
    ]
  );
}
