{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.server.web.fetlife;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  port = 6969;
  hasPkg = inputs ? fetlife-browser && inputs.fetlife-browser ? packages;
  fetlifePkg =
    if hasPkg
    then inputs.fetlife-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    else null;
in {
  options.features.server.web.fetlife = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        fetlife-browser = {
          url = "git+ssh://git@github.com/C10udburst/fetlife-browser.git";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf (cfg && hasPkg) (
      lib.mkMerge [
        (webHelper.mkWebApp {
          name = "fetlife";
          aliases = [
            "fl"
          ];
          port = port;
          suspend = "fetlife.service";
        })
        {
          users.users.fetlife = {
            isSystemUser = true;
            group = "fetlife";
            home = "${storage}/fetlife";
          };
          users.groups.fetlife = {};

          systemd.tmpfiles.rules = [
            "d ${storage}/fetlife 0750 fetlife fetlife - -"
          ];

          systemd.services.fetlife = {
            description = "Fetlife";
            wantedBy = ["multi-user.target"];
            after = ["network.target"];
            environment = {
              PORT = toString port;
              HOST = "127.0.0.1";
              FETLIFE_DATA_DIR = "${storage}/fetlife";
            };
            serviceConfig = {
              ExecStart = "${fetlifePkg}/bin/fetlife-browser";
              User = "fetlife";
              Group = "fetlife";
              WorkingDirectory = "${storage}/fetlife";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        }
      ]
    ))
  ];
}
