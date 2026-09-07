{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave.apps.other;
  braveEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.brave.enable
    && config.features.gui.apps.brave.apps.enable;
  icons = inputs.webicons.packages.${pkgs.system} or {};
  mkWebApp = import ../_mkwebapp.nix {inherit lib pkgs;};
  isVscode =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable
    && (config.features.gui.apps.editors.vscode or false);
in {
  options.features.gui.apps.brave.apps.other = lib.mkOption {
    type = lib.types.bool;
    default = braveEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages =
      [
        (mkWebApp {
          name = "XTB xStation 5";
          url = "https://xstation5.xtb.com/";
          icon = icons.xtb or "";
          size = "1280,850";
          categories = [
            "Office"
            "Finance"
          ];
        })
        (mkWebApp {
          name = "Fetlife DB";
          url = "http://go/b/fl";
          icon = icons.fetlife or "";
          size = "730,1000";
          categories = [
            "Network"
            "Chat"
          ];
        })
      ]
      ++ lib.optionals (config.features.gui.apps.threed.enable or false) [
        (mkWebApp {
          name = "Gridfinity Cutout";
          url = "https://gridfinity-cutout.pages.dev/";
          icon = icons.gridfinity or "";
          categories = [
            "Graphics"
            "3DGraphics"
            "Utility"
          ];
        })
      ]
      ++ lib.optionals (!isVscode) [
        (mkWebApp {
          name = "VS Code Web";
          url = "https://vscode.dev";
          icon = icons.vscode or "";
          categories = [
            "Development"
            "IDE"
            "TextEditor"
          ];
        })
      ];
  };
}
