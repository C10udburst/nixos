{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.konsole;

  renderUtils = import ../../render-template.nix {inherit pkgs config lib;};
  renderJinja2 = renderUtils.renderJinja2;
  cleanColors = renderUtils.cleanColors;

  colorscheme = renderJinja2 "Base16-Stylix.colorscheme" ./Base16-Stylix.colorscheme.j2 cleanColors;

  fontName = config.stylix.fonts.monospace.name or "JetBrainsMono Nerd Font";
  fontSize = toString (config.stylix.fonts.sizes.terminal or 11);
  fontValue = "${fontName},${fontSize},-1,5,50,0,0,0,0,0";

  baseProfile = renderJinja2 "Base.profile" ./Konsole.profile.j2 {
    name = "Base";
    parent = "FALLBACK/";
    command = "";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    accent = cleanColors.base0D;
  };

  defaultProfile = renderJinja2 "Default.profile" ./Konsole.profile.j2 {
    name = "Default";
    parent = "Base.profile";
    command = "";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    accent = cleanColors.base0D;
  };

  nushellProfile = renderJinja2 "Nushell.profile" ./Konsole.profile.j2 {
    name = "Nushell";
    parent = "Base.profile";
    command = "${pkgs.nushell}/bin/nu";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    accent = cleanColors.base0D;
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
        "konsole/Base16-Stylix.colorscheme".source = colorscheme;
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
