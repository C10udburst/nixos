{
  config,
  lib,
  ...
}: let
  cfg = config.features.services.vpn;
in {
  options.features.services.vpn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.services.enable && true;
    };
  };
}
