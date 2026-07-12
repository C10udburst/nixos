{
  config,
  lib,
  pkgs,
  ...
}: let
  renderUtils = import ../render-template.nix {inherit pkgs config lib;};
  renderedSvg = renderUtils.renderJinja2 "wallpaper.svg" ./wallpaper.svg.j2 renderUtils.cleanColors;
  renderedPng =
    pkgs.runCommand "wallpaper.png" {
      nativeBuildInputs = [pkgs.librsvg];
    } ''
      rsvg-convert -o "$out" "${renderedSvg}"
    '';
in {
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.breeze-icons
    hicolor-icon-theme
    #libsForQt5.qtstyleplugin-kvantum
    #kdePackages.qtstyleplugin-kvantum
  ];

  stylix = {
    enable = true;
    polarity = "dark";
    image = renderedPng;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest-dark-medium.yaml";
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
      # Explicit sizes prevent Stylix from deriving an inflated Xft.dpi
      # that causes GTK apps (Chrome, Brave) to render context menus larger
      # than Qt/native Wayland apps on 1080p displays.
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
