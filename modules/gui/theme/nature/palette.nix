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
      scheme = "Nature";
      slug = "nature";
      author = "cloudburst";
      base00 = "131513"; # background
      base01 = "151a15"; # color0 (same as background — no lighter bg in xresources)
      base02 = "687d68"; # color8 (bright black)
      base03 = "6c786c"; # color8 (duplicated — no dedicated comment color)
      base04 = "7c9e7c"; # color7 (duplicated — no darker foreground)
      base05 = "8ca68c"; # foreground
      base06 = "8ca68c"; # color7 (duplicated — no lighter foreground)
      base07 = "f0fff0"; # color15 (lightest foreground)
      base08 = "a41d24"; # color1 (red)
      base09 = "f69890"; # color9 (soft red, used as orange stand-in)
      base0A = "faab46"; # color3 (yellow)
      base0B = "1b5836"; # color2 (green)
      base0C = "62a8a8"; # color6 (cyan)
      base0D = "3c5786"; # color4 (blue)
      base0E = "6d4685"; # color5 (magenta)
      base0F = "e9b552"; # color9 (duplicated — no brown/deprecated color)
    };
  };
}
