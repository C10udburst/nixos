{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.java;
in {
  options.features.core.java = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable) {
    programs.java = {
      enable = true;
      package = pkgs.jdk;
    };

    environment.sessionVariables = {
      JAVA_HOME = "/run/current-system/sw/lib/openjdk";
    };
  };
}
