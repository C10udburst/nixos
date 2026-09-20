{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.server.web.organizeer;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  port = 8085;
  organizeerPkg = inputs.organizeer.packages.${pkgs.stdenv.hostPlatform.system}.server;
in {
  options.features.server.web.organizeer = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        organizeer = {
          url = "git+ssh://git@github.com/C10udburst/Organizeer.git";
        };
      };
    }
    (lib.mkIf (cfg && inputs ? organizeer && inputs.organizeer ? packages) (
      lib.mkMerge [
        (webHelper.mkWebApp {
          name = "tasks";
          aliases = [
            "organizeer"
            "todo"
          ];
          port = port;
        })
        {
          users.users.organizeer = {
            isSystemUser = true;
            group = "organizeer";
            home = "${storage}/organizeer";
          };
          users.groups.organizeer = {};

          systemd.tmpfiles.rules = [
            "d ${storage}/organizeer 2750 organizeer web - -"
          ];

          systemd.services.organizeer = {
            description = "Organizeer Task & Habit Manager Server";
            wantedBy = ["multi-user.target"];
            after = ["network.target"];
            environment = {
              PORT = toString port;
              HOST = "127.0.0.1";
              KSTORE_DIR = "${storage}/organizeer";
            };
            serviceConfig = {
              ExecStart = "${organizeerPkg}/bin/organizeer-server";
              User = "organizeer";
              Group = "organizeer";
              WorkingDirectory = "${storage}/organizeer";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        }
      ]
    ))
  ];
}
