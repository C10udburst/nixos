{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.boot;
in {
  options.features.core.boot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
    timeout = lib.mkOption {
      type = lib.types.int;
      default = 2;
    };
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable) {
    boot.loader.timeout = cfg.timeout;
  };
}
