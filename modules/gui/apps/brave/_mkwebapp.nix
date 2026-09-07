{
  lib,
  pkgs,
}: {
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
    builtins.replaceStrings
    [
      " "
      "/"
      ":"
      "."
    ]
    [
      "-"
      "-"
      ""
      "-"
    ]
    name
  );
  windowSizeArg =
    if size != ""
    then " --window-size=${size}"
    else "";
  withoutProto = lib.last (builtins.split "://" url);
  urlParts = builtins.filter (x: builtins.isString x && x != "") (builtins.split "/" withoutProto);
  host = builtins.head urlParts;
  pathParts = builtins.tail urlParts;
  pathStr =
    if pathParts == []
    then "__"
    else "_" + (lib.concatStringsSep "_" pathParts);
  wmClass = "brave-" + host + pathStr + "-Default";
in
  pkgs.makeDesktopItem {
    name = "webapp-${sanitizedName}";
    desktopName = name;
    exec = "brave --app=${url}${windowSizeArg}";
    icon =
      if icon != ""
      then icon
      else "brave-browser";
    startupWMClass = wmClass;
    terminal = false;
    type = "Application";
    inherit categories;
    comment =
      if comment != ""
      then comment
      else "${name} Web Application";
  }
