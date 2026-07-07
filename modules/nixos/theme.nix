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
    image = config.lib.stylix.pixel "base00";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine.yaml";
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
    };
    targets.qt.platform = "kde";
  };
}
