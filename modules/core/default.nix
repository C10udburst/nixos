{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core;
in {
  options.flake-file = lib.mkOption {
    type = lib.types.submodule {
      freeformType = lib.types.attrsOf lib.types.anything;
    };
    default = {};
  };

  options.features.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    documentation.enable = false;
    networking.networkmanager.enable = true;
    services.upower.enable = lib.mkDefault true;
    hardware.i2c.enable = true;

    services.udev.extraRules = ''
      KERNEL=="cec*", SUBSYSTEM=="cec", MODE="0660", GROUP="video"
    '';
  };
}
