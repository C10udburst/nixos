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
    default = (config.features.shell.enable && config.features.shell.utils.enable) && true;
  };

  config = lib.mkIf cfg {
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
