{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled = config.features.gui.dev.programming.enable;
  cfg = config.features.gui.dev.programming.node;
in {
  options.features.gui.dev.programming.node = lib.mkOption {
    type = lib.types.bool;
    default = devEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      nodejs
      pnpm
    ];
  };
}
