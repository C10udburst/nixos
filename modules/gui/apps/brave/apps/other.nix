{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave.apps.other;
  braveEnabled = config.features.gui.apps.brave.apps.enable;
  icons = inputs.webicons.packages.${pkgs.stdenv.hostPlatform.system} or {};
  mkWebApp = import ../_mkwebapp.nix {inherit lib pkgs;};
  isVscode = config.features.gui.apps.editors.vscode.enable or false;
in {
  options.features.gui.apps.brave.apps.other = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = braveEnabled && true;
    };
    vscode = lib.mkOption {
      type = lib.types.bool;
      default = braveEnabled && (!isVscode);
    };
  };

  config = lib.mkIf cfg.enable {
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
          homelab = "fetlife";
          icon = icons.fetlife or "";
          size = "730,1000";
          categories = [
            "Network"
            "Chat"
          ];
        })
        (mkWebApp {
          name = "Pi Web";
          homelab = "pi";
          icon = icons."pi-web" or "";
          categories = [
            "Development"
            "Utility"
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
      ++ lib.optionals (cfg.vscode) [
        (mkWebApp {
          name = "Code";
          homelab = "code";
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
