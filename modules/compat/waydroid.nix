{
  config,
  lib,
  pkgs,
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
    virtualisation.waydroid.package = pkgs.waydroid-nftables;
    # Prevent automatic boot startup while keeping D-Bus activation intact
    systemd.services.waydroid-container.wantedBy = lib.mkForce [];
  };
}
