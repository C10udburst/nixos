{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.theme.nature.palette;
in {
  options.features.gui.theme.nature.palette = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.theme.nature.enable && true;
  };

  config = lib.mkIf cfg {
    stylix.base16Scheme = {
      #https://tinted-theming.github.io/tinted-gallery/#base16-black-metal-burzum
      scheme = "Stylix";
      slug = "stylix";
      author = "Stylix";
      base00 = "000000";
      base01 = "121212";
      base02 = "222222";
      base03 = "333333";
      base04 = "999999";
      base05 = "c1c1c1";
      base06 = "999999"; # Uwaga: w Twojej liście base04/base06 oraz base05/base07 powtarzają się
      base07 = "c1c1c1";
      base08 = "5f8787";
      base09 = "aaaaaa";
      base0A = "99bbaa";
      base0B = "ddeecc";
      base0C = "aaaaaa";
      base0D = "888888";
      base0E = "999999";
      base0F = "444444";
    };
  };
}
