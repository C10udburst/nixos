{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.xdg;
in {
  options.features.gui.xdg = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.enable && true;
  };

  config = lib.mkIf cfg {
    xdg.portal = {
      enable = true;
      wlr = {
        enable = true;
        settings = {
          screencast = {
            chooser_type = "none";
          };
        };
      };
      extraPortals = lib.mkForce (
        (with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
          kdePackages.xdg-desktop-portal-kde
        ])
        ++ lib.optional config.services.gnome.gnome-keyring.enable pkgs.gnome-keyring
      );
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
          default = ["kde"];
          "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
          "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
          "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        };
      };
    };
  };
}
