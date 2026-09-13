{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.theme.font;
in {
  options.features.gui.theme.font = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.theme.enable && true;
  };

  config = lib.mkIf cfg {
    stylix.fonts = {
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
  };
}
