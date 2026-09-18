{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.resume;
  storage = config.features.server.web.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  port = 3100;
in {
  options.features.server.web.resume = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "resume";
        aliases = [
          "cv"
          "rxresume"
          "reactive-resume"
        ];
        port = port;
        suspend = "podman-resume.service";
      })
      {
        age.secrets.resume-env = {
          file = ../../../secrets/resume-env.age;
          owner = "resume";
          group = "resume";
          mode = "0400";
        };

        users.users.resume = {
          isSystemUser = true;
          group = "resume";
          home = "${storage}/resume";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.resume = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/resume 0750 resume resume - -"
          "d ${storage}/resume/data 0750 resume resume - -"
        ];

        services.postgresql = {
          enable = true;
          ensureDatabases = ["reactive_resume"];
          ensureUsers = [
            {
              name = "reactive_resume";
              ensureDBOwnership = true;
            }
          ];
          authentication = lib.mkBefore ''
            host reactive_resume reactive_resume 127.0.0.1/32 trust
            host reactive_resume reactive_resume ::1/128 trust
          '';
        };

        systemd.services.podman-resume = {
          after = ["postgresql.service"];
          requires = ["postgresql.service"];
        };

        virtualisation.oci-containers.containers.resume = {
          image = helpers.resolveImage "ghcr.io/reactive-resume/reactive-resume:latest";
          podman.user = "resume";
          volumes = [
            "${storage}/resume/data:/app/data"
          ];
          extraOptions = [
            "--network=host"
            "--userns=keep-id:uid=1000,gid=1000"
          ];
          environment = {
            PORT = toString port;
            APP_URL = "https://resume.${baseDomain}";
            DATABASE_URL = "postgresql://reactive_resume@127.0.0.1:5432/reactive_resume";
            TZ = config.time.timeZone;
          };
          environmentFiles = [
            config.age.secrets.resume-env.path
          ];
        };
      }
    ]
  );
}
