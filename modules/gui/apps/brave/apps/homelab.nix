{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave.apps.homelab;
  braveEnabled = config.features.gui.apps.brave.apps.enable;
  icons = inputs.webicons.packages.${pkgs.stdenv.hostPlatform.system} or {};
  mkWebApp = import ../_mkwebapp.nix {inherit lib pkgs;};
  isOrganizeer = config.features.gui.apps.tools.organizeer or false;
in {
  options.features.gui.apps.brave.apps.homelab = lib.mkOption {
    type = lib.types.bool;
    default = braveEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages =
      lib.optionals (!isOrganizeer) [
        (mkWebApp {
          name = "Organizeer";
          homelab = "tasks";
          icon = icons.organizeer or "";
          size = "1100,750";
          categories = [
            "Office"
            "Utility"
          ];
        })
      ]
      ++ [
        (mkWebApp {
          name = "Home Assistant";
          homelab = "hass";
          icon = icons.home-assistant or "";
          size = "820,700";
          categories = ["Utility"];
        })
        (mkWebApp {
          name = "Wealthfolio";
          homelab = "wealth";
          icon = icons.wealthfolio or "";
          size = "1024,920";
          categories = [
            "Office"
            "Finance"
          ];
        })
        (mkWebApp {
          name = "SiYuan Notes";
          homelab = "notes";
          icon = icons.siyuan or "";
          size = "1400,800";
          categories = ["Office"];
        })
        (mkWebApp {
          name = "Karakeep Bookmarks";
          homelab = "bookmark";
          icon = icons.karakeep or "";
          size = "1220,640";
          categories = ["Utility"];
        })
        (mkWebApp {
          name = "Tailscale Console";
          url = "https://console.tailscale.com/";
          icon = icons.tailscale or "";
          categories = [
            "Settings"
            "Network"
          ];
        })
      ];
  };
}
