{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.breeze-icons
    hicolor-icon-theme
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
  ];

  stylix = {
    enable = true;
    polarity = "dark";
    image = ./wallpaper.jpg;
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      serif = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 11;
      };
    };
    targets.gtksourceview.enable = false; # fixes cache miss on inkscape
  };
}
