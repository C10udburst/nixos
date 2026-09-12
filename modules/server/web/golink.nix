{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.server.web.golink;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
  port = 8077;
in
{
  options.features.server.web.golink = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    tailscaleAuthKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "go";
        port = port;
      })
      {
        services.caddy.virtualHosts."http://go" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString port}
          '';
        };

        systemd.tmpfiles.rules = [
          "d ${storage}/golink 0755 root root -"
        ];

        systemd.services.golink = {
          description = "GoLink private shortlink service";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart = ''
              ${pkgs.golink}/bin/golink \
                -sqlitedb ${storage}/golink/golink.db \
                -dev-listen 127.0.0.1:${toString port} \
                -verbose
            '';
            Restart = "on-failure";
            RestartSec = "5s";
            EnvironmentFile = lib.mkIf (cfg.tailscaleAuthKeyFile != null) [
              cfg.tailscaleAuthKeyFile
            ];
          };
        };
      }
    ]
  );
}
