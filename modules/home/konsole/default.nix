{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.konsole;

  hexToDec = hex: let
    cleanHex =
      if builtins.substring 0 1 hex == "#"
      then builtins.substring 1 6 hex
      else hex;
    hexVal = {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
      "A" = 10;
      "B" = 11;
      "C" = 12;
      "D" = 13;
      "E" = 14;
      "F" = 15;
    };
    c = s: hexVal.${s};
    parseByte = s: (c (builtins.substring 0 1 s)) * 16 + (c (builtins.substring 1 1 s));
  in "${toString (parseByte (builtins.substring 0 2 cleanHex))},${toString (parseByte (builtins.substring 2 2 cleanHex))},${toString (parseByte (builtins.substring 4 2 cleanHex))}";

  colorschemeText = ''
    [Background]
    Color=${hexToDec config.lib.stylix.colors.base00}

    [BackgroundIntense]
    Color=${hexToDec config.lib.stylix.colors.base03}

    [Foreground]
    Color=${hexToDec config.lib.stylix.colors.base05}

    [ForegroundIntense]
    Color=${hexToDec config.lib.stylix.colors.base07}

    [Color0]
    Color=${hexToDec config.lib.stylix.colors.base00}

    [Color0Intense]
    Color=${hexToDec config.lib.stylix.colors.base03}

    [Color1]
    Color=${hexToDec config.lib.stylix.colors.base08}

    [Color1Intense]
    Color=${hexToDec config.lib.stylix.colors.base08}

    [Color2]
    Color=${hexToDec config.lib.stylix.colors.base0B}

    [Color2Intense]
    Color=${hexToDec config.lib.stylix.colors.base0B}

    [Color3]
    Color=${hexToDec config.lib.stylix.colors.base0A}

    [Color3Intense]
    Color=${hexToDec config.lib.stylix.colors.base0A}

    [Color4]
    Color=${hexToDec config.lib.stylix.colors.base0D}

    [Color4Intense]
    Color=${hexToDec config.lib.stylix.colors.base0D}

    [Color5]
    Color=${hexToDec config.lib.stylix.colors.base0E}

    [Color5Intense]
    Color=${hexToDec config.lib.stylix.colors.base0E}

    [Color6]
    Color=${hexToDec config.lib.stylix.colors.base0C}

    [Color6Intense]
    Color=${hexToDec config.lib.stylix.colors.base0C}

    [Color7]
    Color=${hexToDec config.lib.stylix.colors.base05}

    [Color7Intense]
    Color=${hexToDec config.lib.stylix.colors.base07}
  '';

  renderUtils = import ../../render-template.nix {inherit pkgs config lib;};
  renderJinja2 = renderUtils.renderJinja2;

  fontName = config.stylix.fonts.monospace.name or "JetBrainsMono Nerd Font";
  fontSize = toString (config.stylix.fonts.sizes.terminal or 11);
  fontValue = "${fontName},${fontSize},-1,5,50,0,0,0,0,0";

  baseProfile = renderJinja2 "Base.profile" ./Konsole.profile.j2 {
    name = "Base";
    parent = "FALLBACK/";
    command = "";
    inherit_container_context = "true";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    word_mode = "true";
    border_when_active = "true";
    focus_border_color = hexToDec config.lib.stylix.colors.base0D;
    cursor_shape = "1";
    blinking_cursor_enabled = "true";
    animating_cursor_enabled = "true";
    line_numbers = "1";
    trim_leading_spaces = "true";
    trim_trailing_spaces = "true";
    url_hints_modifiers = "67108864";
    underline_files_enabled = "true";
  };

  defaultProfile = renderJinja2 "Default.profile" ./Konsole.profile.j2 {
    name = "Default";
    parent = "Base.profile";
    command = "";
    inherit_container_context = "true";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    word_mode = "true";
    border_when_active = "true";
    focus_border_color = hexToDec config.lib.stylix.colors.base0D;
    cursor_shape = "1";
    blinking_cursor_enabled = "true";
    animating_cursor_enabled = "true";
    line_numbers = "1";
    trim_leading_spaces = "true";
    trim_trailing_spaces = "true";
    url_hints_modifiers = "67108864";
    underline_files_enabled = "true";
  };

  nushellProfile = renderJinja2 "Nushell.profile" ./Konsole.profile.j2 {
    name = "Nushell";
    parent = "Base.profile";
    command = "${pkgs.nushell}/bin/nu";
    inherit_container_context = "true";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    word_mode = "true";
    border_when_active = "true";
    focus_border_color = hexToDec config.lib.stylix.colors.base0D;
    cursor_shape = "1";
    blinking_cursor_enabled = "true";
    animating_cursor_enabled = "true";
    line_numbers = "1";
    trim_leading_spaces = "true";
    trim_trailing_spaces = "true";
    url_hints_modifiers = "67108864";
    underline_files_enabled = "true";
  };

  nushellEnabled = config.homeSettings.nushell.enable or false;
  nushellIsDefault = nushellEnabled && (config.homeSettings.nushell.default or "none" != "none");
in {
  options.homeSettings.konsole = {
    enable = lib.mkEnableOption "Enable Konsole configuration";
  };

  config = lib.mkIf cfg.enable {
    xdg.dataFile =
      {
        "konsole/Base16-Stylix.colorscheme".text = colorschemeText;
        "konsole/Base.profile".source = baseProfile;
        "konsole/Default.profile".source = defaultProfile;
      }
      // lib.optionalAttrs nushellEnabled {
        "konsole/Nushell.profile".source = nushellProfile;
      };

    programs.plasma.configFile."konsolerc" = {
      "Desktop Entry" = {
        DefaultProfile =
          if nushellIsDefault
          then "Nushell.profile"
          else "Default.profile";
      };
    };
  };
}
