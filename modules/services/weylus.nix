{
  config,
  lib,
  ...
}: let
  cfg = config.features.services.weylus;
in {
  options.features.services.weylus = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.services.enable && cfg) {
    programs.weylus = {
      enable = true;
      openFirewall = true;
      users = ["cloudburst"];
    };
  };
}
