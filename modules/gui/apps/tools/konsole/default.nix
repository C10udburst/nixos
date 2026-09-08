{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.konsole;

  renderUtils = import ../../../../../lib/helpers/jinja.nix {inherit pkgs config lib;};
  inherit (renderUtils) renderJinja2 cleanColors;

  colorscheme = renderJinja2 "Base16-Stylix.colorscheme" ./_Base16-Stylix.colorscheme.j2 cleanColors;

  fontName = config.stylix.fonts.monospace.name or "monospace";
  fontSize = toString (config.stylix.fonts.sizes.terminal or 11);
  fontValue = "${fontName},${fontSize},-1,5,50,0,0,0,0,0";

  baseProfile = renderJinja2 "Base.profile" ./_Konsole.profile.j2 {
    name = "Base";
    parent = "FALLBACK/";
    command = "";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    accent = cleanColors.base0D;
  };

  defaultProfile = renderJinja2 "Default.profile" ./_Konsole.profile.j2 {
    name = "Default";
    parent = "Base.profile";
    command = "";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    accent = cleanColors.base0D;
  };

  nushellProfile = renderJinja2 "Nushell.profile" ./_Konsole.profile.j2 {
    name = "Nushell";
    parent = "Base.profile";
    command = "${pkgs.nushell}/bin/nu";
    color_scheme = "Base16-Stylix";
    font = fontValue;
    accent = cleanColors.base0D;
  };

  nushellCfg = config.features.shell.nushell;
  nushellEnabled = nushellCfg.enable or false;
  nushellIsDefault = nushellEnabled && ((nushellCfg.default or "none") != "none");
in {
  options.features.gui.apps.tools.konsole = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable) && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.kdePackages.konsole];

    home-manager.users.cloudburst = {
      xdg.terminal-exec = {
        enable = true;
        settings = {
          default = ["org.kde.konsole.desktop"];
        };
      };

      home.sessionVariables = {
        TERMINAL = "konsole";
      };

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
  };
}
