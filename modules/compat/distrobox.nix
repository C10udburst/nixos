{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.compat.distrobox;
in {
  options.features.compat.distrobox = lib.mkOption {
    type = lib.types.bool;
    default = config.features.compat.enable && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.distrobox];
  };
}
