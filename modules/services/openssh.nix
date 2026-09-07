{
  config,
  lib,
  ...
}: let
  cfg = config.features.services.openssh;
in {
  options.features.services.openssh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.services.enable
        then true
        else false;
    };
    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf (config.features.services.enable && cfg.enable) {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.passwordAuthentication;
        PermitRootLogin = "no";
      };
    };
  };
}
