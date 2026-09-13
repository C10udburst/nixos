{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.net;
  toolsEnabled = config.features.gui.apps.tools.enable;
in {
  options.features.gui.apps.tools.net = lib.mkOption {
    type = lib.types.bool;
    default = toolsEnabled && true;
  };

  config = lib.mkIf cfg {
    programs.wireshark.enable = true;
    environment.systemPackages = [pkgs.wireshark];
    users.users.cloudburst.extraGroups = ["wireshark"];
  };
}
