{
  config,
  pkgs,
  inputs,
  ...
}: let
  hostSettings = import ./settings.nix;
in {
  imports = [
    ../../modules/home
    inputs.driftwm-noctalia.homeModules.default
  ];

  hostSettings = hostSettings;

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  home.stateVersion = "26.05";
}
