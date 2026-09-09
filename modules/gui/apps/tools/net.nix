{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.net;
  toolsEnabled = config.features.gui.apps.tools.enable;
in {
  options.features.gui.apps.tools.net = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = toolsEnabled && true;
    };
  };

  options.features.gui.tools.net = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.apps.tools.net.enable;
    };
  };

  config = lib.mkIf (cfg.enable || config.features.gui.tools.net.enable) {
    programs.wireshark.enable = true;
    environment.systemPackages = [pkgs.wireshark];
    users.users.cloudburst.extraGroups = ["wireshark"];
  };
}
