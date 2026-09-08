{
  config,
  lib,
  ...
}: let
  cfg = config.features.compat.waydroid;
in {
  options.features.compat.waydroid = lib.mkOption {
    type = lib.types.bool;
    default = config.features.compat.enable && false;
  };

  config = lib.mkIf cfg {
    virtualisation.waydroid.enable = true;
  };
}
