{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.users.cloudburst;
in {
  options.features.core.users.cloudburst = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = (config.features.core.enable && config.features.core.users.enable) && true;
    };
    admin = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["podman"];
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.cloudburst = {
      isNormalUser = true;
      description = "cloudburst";
      extraGroups =
        (lib.optional cfg.admin "wheel")
        ++ (lib.optional config.networking.networkmanager.enable "networkmanager")
        ++ (lib.optional (config.virtualisation.libvirtd.enable or false) "libvirtd")
        ++ (lib.optional (config.programs.wireshark.enable or false) "wireshark")
        ++ [
          "video"
          "audio"
          "render"
          "i2c"
        ]
        ++ cfg.extraGroups;

      packages = with pkgs; [
        kdePackages.kate
      ];

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDr78YYF81SudwLa3sCOjGcdaB7o8bUUGjqq3j92IfwY+DUx1zI6pV9gMxLgXcQTaNVMSVYns433k6PbnDu3wbORyWz58fRjGJUozuwHUVXaQPV9Lrk5LurTdAkGL5Fn6gE5zTYgZL51E30ln6XzYhmZVaaQoCTlhQRIs93v8AEqz5RnnflB0j3huAz12sOC8iJ+LD976+bVZqMkflKL+y1j9y7yvjgMxYvTpsVVD7+GPjAW+tCzReRFhfaHWXCK4HHZ7V7LQ4SSd3sRiQzwesUtIU6rudVWP8SqWDdu+FjNdp6vXRupwtydBxvn7DVkIug7zhQztQlyc0CSKfeXWM9swciScCvDJCmt3MxrCpm1NgQG27gOPTslyjn9xq6W/4eaQUemcKR2BMCtGx2LjifxrROKXdwZm0AOne7H8w+uEfPAxlbZ9Wc9Oko4E8mMqk7dkREVtkNxwRO/CwqWyT5mLLXWQ45o93ZxmidZ4nGg2KsJAgdYGfbRrCE0hYNY78= cloudburst@cloudburst-laptop"
      ];
    };

    security.polkit.enable = true;
    security.sudo.extraConfig = ''
      Defaults env_keep += "SSH_AUTH_SOCK"
    '';

    # User Home Manager co-located setup
    home-manager.users.cloudburst = {
      home.username = "cloudburst";
      home.homeDirectory = "/home/cloudburst";
      home.stateVersion = "26.05";
      programs.home-manager.enable = true;

      xdg.configFile."fontconfig/conf.d/10-hm-fonts.conf".force = true;

      gtk = {
        enable = true;
        gtk2.force = true;
        iconTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
        gtk3.extraConfig = {
          gtk-application-prefer-dark-theme = true;
        };
        gtk4.extraConfig = {
          gtk-application-prefer-dark-theme = true;
        };
      };

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };
    };
  };
}
