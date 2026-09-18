{
  config,
  lib,
  ...
}:
let
  cfg = config.features.server.web;
  apps = cfg.core._apps;
  allDomains = [
    cfg.core.baseDomain
  ]
  ++ lib.map (app: app.name) apps
  ++ lib.concatMap (app: app.aliases or [ ]) apps;
in
{
  options.features.server.web.etcHosts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = { };
    }
    (lib.mkIf cfg.etcHosts.enable {
      networking.hosts."127.0.0.1" = allDomains;
    })
  ];
}
