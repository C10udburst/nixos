{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.jetbrains;
in {
  options.systemSettings.jetbrains = {
    enable = lib.mkEnableOption "Enable JetBrains IDEs (IntelliJ IDEA and PyCharm)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jetbrains.idea
      jetbrains.pycharm
    ];
  };
}
