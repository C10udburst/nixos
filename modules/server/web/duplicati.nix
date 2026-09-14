{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.duplicati;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.duplicati = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "backup";
        aliases = [
          "duplicati"
        ];
        port = 8200;
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/duplicati 0750 duplicati duplicati - -"
        ];

        services.duplicati = {
          enable = true;
          dataDir = "${storage}/duplicati";
          port = 8200;
          interface = "127.0.0.1";
          parameters = ''
            --webservice-allowedhostnames=*
          '';
        };
      }
    ]
  );
}
