{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.social.signal;
  socialEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.tools.enable
    && config.features.gui.apps.tools.social.enable;
in {
  options.features.gui.apps.tools.social.signal = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (socialEnabled && cfg) {
    environment.systemPackages = [pkgs.signal-desktop];
  };
}
