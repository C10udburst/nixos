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
      default = config.features.core.enable && true;
    };
    timeout = lib.mkOption {
      type = lib.types.int;
      default = 2;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.timeout = lib.mkDefault cfg.timeout;
  };
}
