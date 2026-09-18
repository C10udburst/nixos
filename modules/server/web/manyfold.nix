{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.server.web.manyfold;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  imports = lib.optionals (inputs ? ngipkgs && inputs.ngipkgs ? nixosModules) [
    inputs.ngipkgs.nixosModules.services.manyfold
  ];

  options.features.server.web.manyfold = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        ngipkgs.url = "github:ngi-nix/ngipkgs";
      };
    }
    (lib.mkIf (cfg && inputs ? ngipkgs && inputs.ngipkgs ? packages) (
      lib.mkMerge [
        (webHelper.mkWebApp {
          name = "3d";
          aliases = [
            "manyfold"
            "models"
            "stl"
          ];
          port = 3214;
          suspend = "manyfold.service";
        })
        {
          age.secrets.manyfold-env = {
            file = ../../../secrets/manyfold-env.age;
            owner = "manyfold";
            group = "manyfold";
            mode = "0400";
          };

          users.users.manyfold.home = "/opt/manyfold";

          systemd.tmpfiles.rules = [
            "d /opt/manyfold 0750 manyfold manyfold - -"
            "d ${storage}/manyfold 0750 manyfold manyfold - -"
            "d ${storage}/manyfold/libraries 0750 manyfold manyfold - -"
          ];

          services.manyfold = {
            enable = true;
            package = inputs.ngipkgs.packages.${pkgs.stdenv.hostPlatform.system}.manyfold;
            port = 3214;
            settings = {
              DATABASE_ADAPTER = lib.mkDefault "sqlite3";
              DATABASE_NAME = lib.mkDefault "/opt/manyfold/manyfold.sqlite3";
            };
          };

          systemd.services.manyfold.serviceConfig = {
            WorkingDirectory = lib.mkForce "/opt/manyfold";
            StateDirectory = lib.mkForce [];
            EnvironmentFile = [
              config.age.secrets.manyfold-env.path
            ];
          };

          services.redis.servers.manyfold.port = lib.mkDefault 6379;
          services.redis.servers.manyfold.bind = "127.0.0.1";
        }
      ]
    ))
  ];
}
