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
        ++ (
          if (config.virtualisation.libvirtd.enable or false)
          then ["libvirtd"]
          else []
        )
        ++ (
          if config.programs.wireshark.enable
          then ["wireshark"]
          else []
        )
        ++ ["video" "audio" "render" "i2c"];
      packages = with pkgs; [
        kdePackages.kate
      ];
      openssh.authorizedKeys.keys = lib.mkIf (username == "cloudburst") [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDr78YYF81SudwLa3sCOjGcdaB7o8bUUGjqq3j92IfwY+DUx1zI6pV9gMxLgXcQTaNVMSVYns433k6PbnDu3wbORyWz58fRjGJUozuwHUVXaQPV9Lrk5LurTdAkGL5Fn6gE5zTYgZL51E30ln6XzYhmZVaaQoCTlhQRIs93v8AEqz5RnnflB0j3huAz12sOC8iJ+LD976+bVZqMkflKL+y1j9y7yvjgMxYvTpsVVD7+GPjAW+tCzReRFhfaHWXCK4HHZ7V7LQ4SSd3sRiQzwesUtIU6rudVWP8SqWDdu+FjNdp6vXRupwtydBxvn7DVkIug7zhQztQlyc0CSKfeXWM9swciScCvDJCmt3MxrCpm1NgQG27gOPTslyjn9xq6W/4eaQUemcKR2BMCtGx2LjifxrROKXdwZm0AOne7H8w+uEfPAxlbZ9Wc9Oko4E8mMqk7dkREVtkNxwRO/CwqWyT5mLLXWQ45o93ZxmidZ4nGg2KsJAgdYGfbRrCE0hYNY78= cloudburst@cloudburst-laptop"
      ];
    });

    security.polkit.enable = true;
    security.polkit.enablePkexecWrapper = true;
  };
}
