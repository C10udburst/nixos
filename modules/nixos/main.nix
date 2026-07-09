{
  config,
  lib,
  pkgs,
  ...
}: let
in {
  hardware.i2c.enable = true;
  services.udev.extraRules = ''
    KERNEL=="cec*", SUBSYSTEM=="cec", MODE="0660", GROUP="video"
  '';

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
        # Use gnome-keyring for secrets, so i can use it in driftwm and plasma sessions
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
}
