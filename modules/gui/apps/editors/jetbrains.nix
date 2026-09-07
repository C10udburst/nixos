{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.jetbrains;
  editorsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable;

  isDev = config.features.gui.dev.enable or false;
  isProgramming = isDev && (config.features.gui.dev.programming.enable or false);
  isRust = isProgramming && (config.features.gui.dev.programming.rust.enable or false);
  isGo = isProgramming && (config.features.gui.dev.programming.go or false);
  isPython = isDev && (config.features.gui.dev.python.enable or false);
  isKotlin = isProgramming && (config.features.gui.dev.programming.kotlin or false);
in {
  options.features.gui.apps.editors.jetbrains = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf (editorsEnabled && cfg.enable) {
    environment.systemPackages =
      lib.optionals isRust [pkgs.jetbrains.rust-rover]
      ++ lib.optionals isGo [pkgs.jetbrains.goland]
      ++ lib.optionals isPython [pkgs.jetbrains.pycharm]
      ++ lib.optionals isKotlin [pkgs.jetbrains.idea];
  };
}
