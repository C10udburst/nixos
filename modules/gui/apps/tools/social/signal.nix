{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.social.signal;
  socialEnabled = config.features.gui.apps.tools.social.enable;
in {
  options.features.gui.apps.tools.social.signal = lib.mkOption {
    type = lib.types.bool;
    default = socialEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.signal-desktop];
  };
}
