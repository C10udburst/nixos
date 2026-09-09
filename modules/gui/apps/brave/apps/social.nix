{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave.apps.social;
  braveEnabled = config.features.gui.apps.brave.apps.enable;
  icons = inputs.webicons.packages.${pkgs.system} or {};
  mkWebApp = import ../_mkwebapp.nix {inherit lib pkgs;};
in {
  options.features.gui.apps.brave.apps.social = {
    core = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    web = lib.mkOption {
      type = lib.types.bool;
      default = !(config.features.gui.apps.tools.social.enable or false);
    };
  };

  config = lib.mkIf braveEnabled {
    environment.systemPackages =
      lib.optionals cfg.core [
        (mkWebApp {
          name = "Messenger";
          url = "https://messenger.com";
          icon = icons.messenger or "";
          size = "1100,740";
          categories = [
            "Network"
            "InstantMessaging"
            "Chat"
          ];
        })
        (mkWebApp {
          name = "WhatsApp Web";
          url = "https://web.whatsapp.com";
          icon = icons.whatsapp or "";
          size = "1100,740";
          categories = [
            "Network"
            "InstantMessaging"
            "Chat"
          ];
        })
        (mkWebApp {
          name = "Gmail";
          url = "https://mail.google.com";
          icon = icons.gmail or "";
          categories = [
            "Network"
            "Email"
          ];
        })
        (mkWebApp {
          name = "Outlook";
          url = "https://outlook.office.com/mail/";
          icon = icons.outlook or "";
          categories = [
            "Network"
            "Email"
          ];
        })
        (mkWebApp {
          name = "Microsoft Teams";
          url = "https://teams.microsoft.com/v2/";
          icon = icons.teams or "";
          categories = [
            "Network"
            "InstantMessaging"
            "Chat"
          ];
        })
        (mkWebApp {
          name = "Fetlife";
          url = "https://fetlife.com";
          icon = icons.fetlife or "";
          size = "900,1000";
          categories = [
            "Network"
            "Chat"
          ];
        })
      ]
      ++ lib.optionals cfg.web [
        (mkWebApp {
          name = "Discord Web";
          url = "https://discord.com/app";
          icon = icons.discord or "";
          size = "1200,800";
          categories = [
            "Network"
            "InstantMessaging"
            "Chat"
          ];
        })
        (mkWebApp {
          name = "Telegram Web";
          url = "https://web.telegram.org/a/";
          icon = icons.telegram or "";
          size = "1100,740";
          categories = [
            "Network"
            "InstantMessaging"
            "Chat"
          ];
        })
      ];
  };
}
