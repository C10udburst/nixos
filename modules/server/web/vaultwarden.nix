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
  options.features.server.web.vaultwarden = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "vault";
        aliases = [
          "passwd"
          "vaultwarden"
        ];
        port = 8222;
      })
      {
        services.vaultwarden = {
          enable = true;
          config = {
            ROCKET_PORT = 8222;
            DATA_FOLDER = "${storage}/vaultwarden";
            DOMAIN = "https://vault.${baseDomain}";
          };
        };
      }
    ]
  );
}
