{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave.apps.office;
  braveEnabled = config.features.gui.apps.brave.apps.enable;
  icons = inputs.webicons.packages.${pkgs.stdenv.hostPlatform.system} or {};
  mkWebApp = import ../_mkwebapp.nix {inherit lib pkgs;};
  hasOffice =
    (config.features.gui.apps.editors.office.libreoffice or false)
    || (
      (config.features.gui.apps.editors.artcraft.gridcraft or false)
      && (config.features.gui.apps.editors.artcraft.wordcraft or false)
      && (config.features.gui.apps.editors.artcraft.deckcraft or false)
    );
in {
  options.features.gui.apps.brave.apps.office = lib.mkOption {
    type = lib.types.bool;
    default = braveEnabled && (!hasOffice);
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [
      (mkWebApp {
        name = "Google Docs";
        url = "https://docs.google.com/document";
        icon = icons.google-docs or "";
        categories = [
          "Office"
          "WordProcessor"
        ];
      })
      (mkWebApp {
        name = "Google Sheets";
        url = "https://docs.google.com/spreadsheets";
        icon = icons.google-sheets or "";
        categories = [
          "Office"
          "Spreadsheet"
        ];
      })
      (mkWebApp {
        name = "Google Slides";
        url = "https://docs.google.com/presentation";
        icon = icons.google-slides or "";
        categories = [
          "Office"
          "Presentation"
        ];
      })
      (mkWebApp {
        name = "Google Forms";
        url = "https://docs.google.com/forms";
        icon = icons.google-forms or "";
        categories = ["Office"];
      })
      (mkWebApp {
        name = "Draw.io";
        url = "https://app.diagrams.net";
        icon = icons.drawio or "";
        categories = [
          "Graphics"
          "Office"
        ];
      })
      (mkWebApp {
        name = "Google Calendar";
        url = "https://calendar.google.com";
        icon = icons.google-calendar or "";
        categories = [
          "Office"
          "Calendar"
        ];
      })
    ];
  };
}
