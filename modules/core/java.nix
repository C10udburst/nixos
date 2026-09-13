{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.java;
in {
  options.features.core.java = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.enable && true;
  };

  config = lib.mkIf cfg {
    programs.java = {
      enable = true;
      package = pkgs.jdk;
    };

    environment.sessionVariables = {
      JAVA_HOME = "/run/current-system/sw/lib/openjdk";
    };
  };
}
