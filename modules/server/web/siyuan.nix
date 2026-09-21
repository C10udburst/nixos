{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.features.server.web.siyuan;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.siyuan = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "notes";
        aliases = [
          "siyuan"
          "markdown"
          "note"
        ];
        port = 6806;
        suspend = "siyuan.service";
      })
      {
        age.secrets.siyuan-env = {
          file = ../../../secrets/siyuan-env.age;
          owner = "siyuan";
          group = "siyuan";
          mode = "0400";
        };

        users.users.siyuan = {
          isSystemUser = true;
          group = "siyuan";
          home = "${storage}/siyuan";
        };
        users.groups.siyuan = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/siyuan 2750 siyuan web - -"
        ];

        systemd.services.siyuan = {
          description = "SiYuan note-taking service";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          serviceConfig = {
            ExecStart = ''
              ${pkgsUnstable.siyuan.kernel}/bin/kernel serve \
                --workspace=${storage}/siyuan \
                --wd=${pkgs.siyuan}/share/siyuan/resources \
                --port=6806
            '';
            User = "siyuan";
            Group = "siyuan";
            WorkingDirectory = "${storage}/siyuan";
            EnvironmentFile = config.age.secrets.siyuan-env.path;
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      }
    ]
  );
}
