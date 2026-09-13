{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.copyparty;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.copyparty = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "files";
        aliases = [
          "file"
          "drive"
          "copyparty"
        ];
        port = 3923;
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/copyparty 0755 root root -"
        ];

        systemd.services.copyparty = {
          description = "Copyparty file server";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          serviceConfig = {
            ExecStart = ''
              ${pkgs.copyparty}/bin/copyparty \
                -p 3923 \
                -a 127.0.0.1 \
                -v ${storage}/copyparty:/:rw
            '';
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      }
    ]
  );
}
