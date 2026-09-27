{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.theme.palette;
in {
  options.features.gui.theme.palette = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.theme.enable && true;
  };

  config = lib.mkIf cfg {
    stylix.base16Scheme = {
      scheme = "Stylix";
      slug = "stylix";
      author = "Stylix";
      base00 = "1e1e24"; # Default Background (Dialogue Background)
      base01 = "25252d"; # Lighter Background (Status bars, line highlights)
      base02 = "3c3c46"; # Selection Background
      base03 = "60606e"; # Comments, Invisible Characters
      base04 = "a8a8b2"; # Dark Foreground (Carets, Delimiters)
      base05 = "fffdf2"; # Default Foreground (Text / Ivory White)
      base06 = "ffffff"; # Light Foreground
      base07 = "fffffa"; # Light Background
      base08 = "cd3131"; # Variables, Failures, Crimson Red
      base09 = "e45325"; # Integers, Boolean, Physique Red-Orange
      base0A = "c6ed45"; # Classes, Keywords, Motorics Yellow-Green
      base0B = "3df1a3"; # Strings, Success Mint Green
      base0C = "61b2ed"; # Support, Intellect Blue
      base0D = "ffa500"; # Functions, Methods, Kim Kitsuragi Amber
      base0E = "a24fd6"; # Keywords, Psyche Purple
      base0F = "b8860b"; # Deprecated, Dark Goldenrod
    };
  };
}
