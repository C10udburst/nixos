{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.desktop.driftwm;
  isSlow = config.features.core.hardware.slow or false;
in {
  options.features.gui.desktop.driftwm.desktop = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.gui.enable && config.features.gui.desktop.enable && cfg.enable) && (!isSlow);
  };

  config = lib.mkIf cfg.desktop {
    environment.systemPackages = lib.optionals (
      inputs ? driftwm-desktop
      && inputs.driftwm-desktop ? packages
      && inputs.driftwm-desktop.packages ? ${pkgs.stdenv.hostPlatform.system}
    ) [inputs.driftwm-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default];
  };
}
