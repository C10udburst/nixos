{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.powerkey;
in {
  options.features.gui.powerkey = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.enable && true;
  };

  config = lib.mkIf cfg {
    # Power button suspends (via logind) instead of powering off, on every
    # graphical device. Noctalia's lock_before_suspend locks the session on
    # PrepareForSleep, so suspend from the button lands on the lock screen.
    services.logind.settings.Login.HandlePowerKey = "suspend";
  };
}
