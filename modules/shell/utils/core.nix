{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.core;
in {
  options.features.shell.utils.core = lib.mkOption {
    type = lib.types.bool;
    default =
      if (config.features.shell.enable && config.features.shell.utils.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.utils.enable && cfg) {
    environment.systemPackages = with pkgs; [
      screen
      jq
      curl
      wget
      file
      killall
    ];
  };
}
