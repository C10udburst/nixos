{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.vaultwarden;
  storage = config.features.server.web.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.vaultwarden = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "vault";
        aliases = [
          "passwd"
          "vaultwarden"
        ];
        port = 8222;
        suspend = [
          "vaultwarden.service"
        ];
      })
      {
        age.secrets.vaultwarden-env = {
          file = ../../../secrets/vaultwarden-env.age;
        };

        systemd.tmpfiles.rules = [
          "d ${storage}/vaultwarden 2750 vaultwarden web - -"
        ];

        systemd.services.vaultwarden.serviceConfig.ReadWritePaths = [
          "${storage}/vaultwarden"
        ];

        services.vaultwarden = {
          enable = true;
          environmentFile = config.age.secrets.vaultwarden-env.path;
          config = {
            ROCKET_PORT = 8222;
            ENABLE_WEBSOCKET = true;
            DATA_FOLDER = "${storage}/vaultwarden";
            DOMAIN = "https://vault.${baseDomain}";
          };
        };
      }
    ]
  );
}
