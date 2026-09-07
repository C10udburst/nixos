{
  config,
  lib,
  pkgs,
  ...
}: let
  compatEnabled = config.features.compat.enable;
  cfg = config.features.compat.distrobox;
in {
  options.features.compat.distrobox = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (compatEnabled && cfg) {
    environment.systemPackages = [pkgs.distrobox];
  };
}
