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
    enableVkms = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Load the VKMS (Virtual Kernel Mode Setting) DRM kernel module so Wayland compositors can create headless outputs";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.weylus = {
      enable = true;
      openFirewall = cfg.openFirewall;
      users = allUsers;
    };

    boot.kernelModules = lib.mkIf cfg.enableVkms ["vkms"];
    boot.extraModprobeConfig = lib.mkIf cfg.enableVkms ''
      options vkms enable_cursor=1 enable_overlay=1 enable_writeback=1
    '';
  };
}
