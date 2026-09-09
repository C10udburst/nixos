{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.social.telegram;
  socialEnabled = config.features.gui.apps.tools.social.enable;
in {
  options.features.gui.apps.tools.social.telegram = lib.mkOption {
    type = lib.types.bool;
    default = socialEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.telegram-desktop];
  };
}
