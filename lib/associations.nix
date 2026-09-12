{lib, ...}: let
  associatePackage = pkg: let
    appsPath = "${pkg}/share/applications";
    desktopFiles =
      if builtins.pathExists appsPath
      then builtins.filter (name: lib.hasSuffix ".desktop" name) (builtins.attrNames (builtins.readDir appsPath))
      else [];

    extractMimeTypes = desktopFile: let
      content = builtins.readFile "${appsPath}/${desktopFile}";
      lines = lib.splitString "\n" content;
      mimeTypeLines = builtins.filter (line: lib.hasPrefix "MimeType=" line) lines;
    in
      if mimeTypeLines == []
      then []
      else let
        mimeTypeValue = lib.removePrefix "MimeType=" (builtins.head mimeTypeLines);
      in
        builtins.filter (x: x != "") (lib.splitString ";" mimeTypeValue);

    mapDesktopFile = desktopFile:
      map (mimeType: {
        name = mimeType;
        value = [desktopFile];
      }) (extractMimeTypes desktopFile);

    allMappings = lib.concatMap mapDesktopFile desktopFiles;
  in
    builtins.listToAttrs allMappings;
in {
  inherit associatePackage;
}
