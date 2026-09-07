{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled =
    config.features.gui.enable
    && config.features.gui.dev.enable
    && config.features.gui.dev.programming.enable;
  cfg = config.features.gui.dev.programming.rust;
in {
  options.features.gui.dev.programming.rust = lib.mkOption {
    type = lib.types.bool;
    default = devEnabled && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      rustc
      cargo
    ];
  };
}
