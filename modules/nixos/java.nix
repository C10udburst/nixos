{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.java;
in {
  options.systemSettings.java = {
    enable = lib.mkEnableOption "Enable Java Development Kit (JDK)";
  };

  config = lib.mkIf cfg.enable {
    programs.java = {
      enable = true;
      package = pkgs.jdk;
    };
  };
}
