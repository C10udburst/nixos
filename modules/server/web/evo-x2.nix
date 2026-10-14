{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.evo-x2;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.evo-x2 = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    webHelper.mkWebApp {
      name = "evo-x2";
      aliases = [
        "llm-x2"
      ];
      upstream = "llm.wilkins.pl.eu.org:8080";
      cors = true;
    }
  );
}
