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
      default = config.features.services.enable && true;
    };
    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.passwordAuthentication;
        PermitRootLogin = "no";
      };
    };
  };
}
