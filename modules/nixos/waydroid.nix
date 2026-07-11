{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.waydroid;
in {
  options.systemSettings.waydroid = {
    enable = lib.mkEnableOption "Enable declarative Waydroid";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.waydroid.enable = true;
    virtualisation.waydroid.package = pkgs.waydroid-nftables;
  };
}
