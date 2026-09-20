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
        age.secrets.duplicati-pass = {
          file = ../../../secrets/duplicati-pass.age;
          owner = "duplicati";
          group = "duplicati";
          mode = "0400";
        };

        users.users.duplicati.extraGroups = ["web"];

        systemd.tmpfiles.rules = [
          "d ${storage}/duplicati 2750 duplicati web - -"
        ];

        services.duplicati = {
          enable = true;
          dataDir = "${storage}/duplicati";
          port = 8200;
          interface = "127.0.0.1";
          parametersFile = "/run/duplicati/parameters";
        };

        systemd.services.duplicati = {
          serviceConfig = {
            RuntimeDirectory = "duplicati";
            RuntimeDirectoryMode = "0700";
          };
          preStart = ''
            {
              echo "--webservice-allowedhostnames=*"
              printf -- "--webservice-password=%s\n" "$(< ${config.age.secrets.duplicati-pass.path})"
            } > /run/duplicati/parameters
          '';
        };
      }
    ]
  );
}
