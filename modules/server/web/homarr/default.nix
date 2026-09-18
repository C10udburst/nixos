{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.homarr;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  baseDomain = webCfg.core.baseDomain or "example.com";
  webHelper = import ../_webService.nix {inherit config lib pkgs;};

  rawApps = webCfg.core._apps or [];
  filteredApps = builtins.filter (a: a.name != "home") rawApps;

  declarativeApps =
    map (app: {
      id = "declarative-${app.name}";
      name = app.name;
      href = "https://${app.name}.${baseDomain}";
      icon_url = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/${app.name}.svg";
      description = "";
      ping_url = "";
    })
    filteredApps;

  appsJsonFile = pkgs.writeText "homarr-apps.json" (builtins.toJSON declarativeApps);
in {
  options.features.server.web.homarr = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "home";
        aliases = [
          "homarr"
          "homepage"
        ];
        port = 7575;
      })
      {
        age.secrets.homarr-env = {
          file = ../../../../secrets/homarr-env.age;
          owner = "homarr";
          group = "homarr";
          mode = "0400";
        };

        users.users.homarr = {
          isSystemUser = true;
          group = "homarr";
          home = "${storage}/homarr";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.homarr = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/homarr 0750 homarr homarr - -"
          "d ${storage}/homarr/appdata 0750 homarr homarr - -"
        ];

        systemd.services.homarr-declarative-apps = {
          description = "Synchronize declarative apps with Homarr database";
          wantedBy = ["multi-user.target"];
          after = ["podman-homarr.service"];
          serviceConfig = {
            Type = "oneshot";
            User = "homarr";
            Group = "homarr";
            ExecStart = "${pkgs.python3}/bin/python3 ${./_sync-apps.py} ${storage}/homarr/appdata/db/db.sqlite ${appsJsonFile}";
          };
        };

        virtualisation.oci-containers.containers.homarr = {
          image = helpers.resolveImage "ghcr.io/homarr-labs/homarr:latest";
          podman.user = "homarr";
          ports = [
            "127.0.0.1:7575:7575"
          ];
          volumes = [
            "${storage}/homarr/appdata:/appdata"
          ];
          environmentFiles = [
            config.age.secrets.homarr-env.path
          ];
        };
      }
    ]
  );
}
