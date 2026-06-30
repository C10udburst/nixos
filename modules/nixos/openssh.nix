{
  config,
  lib,
  ...
}: let
  cfg = config.systemSettings.openssh;
in {
  options.systemSettings.openssh = {
    enable = lib.mkEnableOption "Enable OpenSSH daemon";
  };

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
  };
}
