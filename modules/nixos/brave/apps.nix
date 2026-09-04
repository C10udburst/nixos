{
  config,
  lib,
  pkgs,
  icons,
  ...
}: let
  cfg = config.systemSettings.brave;

  webApp = {
    url,
    name,
    icon ? "",
    size ? "",
    comment ? "",
    categories ? [
      "Network"
      "WebBrowser"
    ],
  }: let
    sanitizedName = lib.strings.toLower (
      builtins.replaceStrings [" " "/" ":" "."] ["-" "-" "" "-"] name
    );
    windowSizeArg =
      if size != ""
      then " --window-size=${size}"
      else "";
  in
    pkgs.makeDesktopItem {
      name = "webapp-${sanitizedName}";
      desktopName = name;
      exec = "brave --app=${url}${windowSizeArg}";
      icon =
        if icon != ""
        then icon
        else "brave-browser";
      terminal = false;
      type = "Application";
      inherit categories;
      comment =
        if comment != ""
        then comment
        else "${name} Web Application";
    };

  googleWebSuite = [
    (webApp {
      name = "Google Docs";
      url = "https://docs.google.com/document";
      icon = icons.google-docs;
      categories = [
        "Office"
        "WordProcessor"
      ];
    })
    (webApp {
      name = "Google Sheets";
      url = "https://docs.google.com/spreadsheets";
      icon = icons.google-sheets;
      categories = [
        "Office"
        "Spreadsheet"
      ];
    })
    (webApp {
      name = "Google Slides";
      url = "https://docs.google.com/presentation";
      icon = icons.google-slides;
      categories = [
        "Office"
        "Presentation"
      ];
    })
    (webApp {
      name = "Google Forms";
      url = "https://docs.google.com/forms";
      icon = icons.google-forms;
      categories = ["Office"];
    })
  ];

  isVscodeEnabled =
    if builtins.isAttrs (config.hostSettings.vscode or true)
    then config.hostSettings.vscode.enable or true
    else config.hostSettings.vscode or true;

  isSocialEnabled =
    if builtins.isAttrs (config.hostSettings.social or false)
    then config.hostSettings.social.enable or false
    else config.hostSettings.social or false;

  defaultWebApps =
    [
      (webApp {
        name = "Wealthfolio";
        url = "http://go/b/wealth";
        icon = icons.wealthfolio;
        size = "1024,920";
        categories = [
          "Office"
          "Finance"
        ];
      })
      (webApp {
        name = "Immich Photos";
        url = "http://go/b/photos";
        icon = icons.immich;
        size = "1240,760";
        categories = [
          "Graphics"
          "Photography"
        ];
      })
      (webApp {
        name = "Home Assistant";
        url = "http://go/b/hass";
        icon = icons.home-assistant;
        size = "820,700";
        categories = ["Utility"];
      })
      (webApp {
        name = "SiYuan Notes";
        url = "http://go/b/notes";
        icon = icons.siyuan;
        size = "1400,800";
        categories = ["Office"];
      })
      (webApp {
        name = "Fetlife DB";
        url = "http://go/b/fl";
        icon = icons.fetlife;
        size = "730,1000";
        categories = [
          "Network"
          "Chat"
        ];
      })
      (webApp {
        name = "Karakeep Bookmarks";
        url = "http://go/b/bookmark";
        icon = icons.karakeep;
        size = "1220,640";
        categories = ["Utility"];
      })

      (webApp {
        name = "Fetlife";
        url = "https://fetlife.com";
        icon = icons.fetlife;
        size = "900,1000";
        categories = [
          "Network"
          "Chat"
        ];
      })
      (webApp {
        name = "Messenger";
        url = "https://messenger.com";
        icon = icons.messenger;
        size = "1100,740";
        categories = [
          "Network"
          "InstantMessaging"
          "Chat"
        ];
      })
      (webApp {
        name = "Gmail";
        url = "https://mail.google.com";
        icon = icons.gmail;
        categories = [
          "Network"
          "Email"
        ];
      })
      (webApp {
        name = "WhatsApp Web";
        url = "https://web.whatsapp.com";
        icon = icons.whatsapp;
        size = "1100,740";
        categories = [
          "Network"
          "InstantMessaging"
          "Chat"
        ];
      })
    ]
    ++ lib.optionals (!config.systemSettings.office.enable) googleWebSuite
    ++ lib.optionals (!isVscodeEnabled) [
      (webApp {
        name = "VS Code Web";
        url = "https://vscode.dev";
        icon = icons.vscode;
        categories = [
          "Development"
          "IDE"
          "TextEditor"
        ];
      })
    ]
    ++ lib.optionals (!isSocialEnabled) [
      (webApp {
        name = "Telegram Web";
        url = "https://web.telegram.org";
        icon = icons.telegram;
        categories = [
          "Network"
          "InstantMessaging"
          "Chat"
        ];
      })
      (webApp {
        name = "Discord Web";
        url = "https://discord.com/app";
        icon = icons.discord;
        categories = [
          "Network"
          "InstantMessaging"
          "Chat"
        ];
      })
    ]
    ++ lib.optionals config.systemSettings.threed.enable [
      (webApp {
        name = "Gridfinity Cutout";
        url = "https://gridfinity-cutout.pages.dev/";
        icon = icons.gridfinity;
        categories = [
          "Graphics"
          "3DGraphics"
          "Utility"
        ];
      })
    ];

  convertUserWebApp = item:
    if lib.isDerivation item
    then item
    else if builtins.isAttrs item
    then webApp item
    else if builtins.isString item
    then
      webApp {
        url = item;
        name = item;
      }
    else throw "Unsupported webapp entry: ${builtins.toJSON item}";

  userDesktopItems = map convertUserWebApp cfg.webapps;
in {
  inherit webApp;
  allDesktopItems = defaultWebApps ++ userDesktopItems;
}
