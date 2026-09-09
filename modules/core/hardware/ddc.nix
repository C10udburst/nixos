{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware.ddc;
in {
  options.features.core.hardware.ddc = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.ddcutil];
    hardware.i2c.enable = true;
    services.udev.extraRules = ''
      KERNEL=="cec*", SUBSYSTEM=="cec", MODE="0660", GROUP="video"
    '';
  };
}
