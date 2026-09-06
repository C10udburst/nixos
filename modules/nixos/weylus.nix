{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.weylus;
  allUsers = lib.unique (config.systemSettings.users ++ config.systemSettings.adminUsers);
in {
  options.systemSettings.weylus = {
    enable = lib.mkEnableOption "weylus (use tablet/phone as graphic tablet/touch screen)";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open firewall ports for Weylus (1701, 9001)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.weylus = {
      enable = true;
      openFirewall = cfg.openFirewall;
      users = allUsers;
    };
  };
}
