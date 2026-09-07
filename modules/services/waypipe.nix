{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.services.waypipe;
in {
  options.features.services.waypipe = lib.mkOption {
    type = lib.types.bool;
    default =
      if config.features.services.enable
      then true
      else false;
  };

  config = lib.mkIf (config.features.services.enable && cfg) {
    environment.systemPackages = [pkgs.waypipe];
    services.openssh.extraConfig = ''
      StreamLocalBindUnlink yes
    '';
  };
}
