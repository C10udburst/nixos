{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings;
  allUsers = lib.unique (cfg.users ++ cfg.adminUsers);
in {
  options.systemSettings = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Standard system users";
    };
    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Admin users (will be added to the wheel group)";
    };
  };

  config = {
    users.users = lib.genAttrs allUsers (username: {
      isNormalUser = true;
      description = username;
      extraGroups =
        (
          if lib.elem username cfg.adminUsers
          then ["wheel"]
          else []
        )
        ++ (
          if config.networking.networkmanager.enable
          then ["networkmanager"]
          else []
        )
        ++ (
          if (config.virtualisation.podman.enable or false)
          then ["podman"]
          else []
        )
        ++ ["video" "audio" "render"];
      packages = with pkgs; [
        kdePackages.kate
        brave
        vscode
      ];
    });
  };
}
