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
    default = config.features.services.enable && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.waypipe];
    services.openssh.extraConfig = ''
      StreamLocalBindUnlink yes
    '';
  };
}
