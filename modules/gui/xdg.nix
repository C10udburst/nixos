{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.xdg;
in {
  options.features.gui.xdg = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };
  };

  config = lib.mkIf (config.features.gui.enable && cfg.enable) {
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
      ];
      config = {
        common = {
          default = ["kde"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        };
        kde = {
          default = ["kde"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        };
        driftwm = {
          default = lib.mkForce ["kde"];
          "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
          "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        };
      };
    };
  };
}
