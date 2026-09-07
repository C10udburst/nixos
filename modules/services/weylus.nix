{
  config,
  lib,
  ...
}: let
  cfg = config.features.services.weylus;
in {
  options.features.services.weylus = lib.mkOption {
    type = lib.types.bool;
    default = config.features.services.enable && false;
  };

  config = lib.mkIf cfg {
    programs.weylus = {
      enable = true;
      openFirewall = true;
      users = ["cloudburst"];
    };
  };
}
