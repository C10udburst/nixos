{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.greeter;
  greeterEnabled = config.features.gui.enable && cfg.enable;
  hasAutologin = (cfg.autologin or null) != null && (cfg.autologin or false) != false;

  autologinCommand =
    if cfg.autologin == "driftwm"
    then "${pkgs.driftwm}/bin/driftwm-session"
    else if cfg.autologin == "plasma"
    then "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland"
    else toString cfg.autologin;
in {
  options.features.gui.greeter.autologin = lib.mkOption {
    type = lib.types.nullOr (lib.types.either lib.types.str lib.types.bool);
    default = null;
  };

  config = lib.mkIf (greeterEnabled && hasAutologin) {
    services.greetd.settings.default_session = lib.mkForce {
      command = autologinCommand;
      user = "cloudburst";
    };
  };
}
