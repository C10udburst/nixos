{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.homeSettings.associations;

  # Helper function to extract MIME types from desktop files in a package
  associatePackage = pkg: let
    appsPath = "${pkg}/share/applications";
    desktopFiles =
      if builtins.pathExists appsPath
      then builtins.filter (name: lib.hasSuffix ".desktop" name) (builtins.attrNames (builtins.readDir appsPath))
      else [];

    # Extract mime types from a single desktop file
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

    # Create mapping: { name = mimeType; value = [ desktopFile ]; }
    mapDesktopFile = desktopFile:
      map (mimeType: {
        name = mimeType;
        value = [desktopFile];
      }) (extractMimeTypes desktopFile);

    allMappings = lib.concatMap mapDesktopFile desktopFiles;
  in
    builtins.listToAttrs allMappings;

  # Custom wrapper for Mayo to add MIME types to its desktop file and prevent crashes
  mayoCustom = pkgs.symlinkJoin {
    name = "mayo-custom";
    paths = [pkgs.mayo];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm -rf $out/share/applications
      mkdir -p $out/share/applications
      cp ${pkgs.mayo}/share/applications/mayo.desktop $out/share/applications/mayo.desktop
      chmod +w $out/share/applications/mayo.desktop
      echo "MimeType=model/stl;model/step;model/iges;model/x3d+xml;model/gltf+json;model/gltf-binary;application/x-step;application/x-iges;application/x-3ds;application/x-obj;application/x-stl;application/sla;model/x-brep;application/x-brep;image/vnd.dxf;application/dxf;model/obj;model/vrml;x-world/x-vrml;application/x-amf;model/ply;application/x-ply;model/x-off;application/x-off;model/3mf;application/vnd.ms-package.3dmanufacturing-3dmodel+xml;image/x-3ds;model/fbx;application/x-fbx;model/vnd.collada+xml;application/x-dae;model/x3d+vrml;model/x-directx;application/x-directx;" >> $out/share/applications/mayo.desktop

      rm -f $out/bin/mayo
      makeWrapper ${pkgs.mayo}/bin/mayo $out/bin/mayo \
        --set vblank_mode 0 \
        --set QT_QPA_PLATFORM "xcb"
    '';
  };

  # 1. Haruna (movies, audio) - parse and filter for video/audio
  harunaMimes = filterAttrs (name: value: hasPrefix "video/" name || hasPrefix "audio/" name) (associatePackage pkgs.haruna);

  # 2. Nomacs (images) - parse and filter for image/
  nomacsMimes = filterAttrs (name: value: hasPrefix "image/" name) (associatePackage pkgs.nomacs);

  # 3. Mayo (CAD formats) - parse all MIME types from custom desktop file
  mayoMimes = associatePackage mayoCustom;

  # 4. Brave browser default types
  braveMimes = {
    "text/html" = ["brave-browser.desktop"];
    "text/xml" = ["brave-browser.desktop"];
    "application/xhtml+xml" = ["brave-browser.desktop"];
    "application/x-mimearchive" = ["brave-browser.desktop"]; # mhtml
    "x-scheme-handler/http" = ["brave-browser.desktop"];
    "x-scheme-handler/https" = ["brave-browser.desktop"];
    "x-scheme-handler/about" = ["brave-browser.desktop"];
    "x-scheme-handler/unknown" = ["brave-browser.desktop"];
    "x-scheme-handler/mailto" = ["brave-browser.desktop"];
  };

  # 5. Dolphin (file browser & archive opener)
  dolphinMimes = {
    "inode/directory" = ["org.kde.dolphin.desktop"];
    "application/zip" = ["org.kde.dolphin.desktop"];
    "application/x-tar" = ["org.kde.dolphin.desktop"];
    "application/x-gzip" = ["org.kde.dolphin.desktop"];
    "application/x-bzip2" = ["org.kde.dolphin.desktop"];
    "application/x-7z-compressed" = ["org.kde.dolphin.desktop"];
    "application/x-rar" = ["org.kde.dolphin.desktop"];
    "application/x-xz" = ["org.kde.dolphin.desktop"];
  };

  # 6. VSCode (programming files)
  vscodeMimes = {
    "text/javascript" = ["code.desktop"];
    "application/javascript" = ["code.desktop"];
    "text/x-python" = ["code.desktop"];
    "text/x-rust" = ["code.desktop"];
    "text/x-c" = ["code.desktop"];
    "text/x-c++" = ["code.desktop"];
    "text/x-go" = ["code.desktop"];
    "text/x-java" = ["code.desktop"];
    "text/plain" = ["code.desktop"];
    "text/x-shellscript" = ["code.desktop"];
    "application/json" = ["code.desktop"];
    "text/markdown" = ["code.desktop"];
    "text/x-nix" = ["code.desktop"];
    "text/x-yaml" = ["code.desktop"];
    "text/x-toml" = ["code.desktop"];
    "text/x-ini" = ["code.desktop"];
    "text/x-xml" = ["code.desktop"];
    "text/x-sql" = ["code.desktop"];
    "text/x-php" = ["code.desktop"];
    "text/x-perl" = ["code.desktop"];
    "text/x-ruby" = ["code.desktop"];
    "text/x-lua" = ["code.desktop"];
    "text/x-haskell" = ["code.desktop"];
    "text/x-scala" = ["code.desktop"];
    "text/x-kotlin" = ["code.desktop"];
    "text/x-vb" = ["code.desktop"];
  };

  # 7. KDE Connect (phones)
  kdeConnectMimes = {
    "x-scheme-handler/tel" = ["org.kde.kdeconnect.handler.desktop"];
    "x-scheme-handler/sms" = ["org.kde.kdeconnect.handler.desktop"];
  };
  # 8. okular (PDFs, eBooks, and documents)
  okularMimes = filterAttrs (
    name: value:
      ! (builtins.any (
          desktopFile:
            lib.hasSuffix "tiff.desktop" desktopFile
            || lib.hasSuffix "txt.desktop" desktopFile
            || lib.hasSuffix "md.desktop" desktopFile
        )
        value)
      && name != "image/tiff"
  ) (associatePackage pkgs.kdePackages.okular);

  # Merge all defaults (with VSCode and others added as secondary/primary accordingly)
  mergedDefaults = foldl' recursiveUpdate {} [
    okularMimes
    harunaMimes
    nomacsMimes
    mayoMimes
    braveMimes
    dolphinMimes
    vscodeMimes
    kdeConnectMimes
  ];
in {
  options.homeSettings.associations = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable custom file associations and default application settings";
    };
  };

  config = mkIf cfg.enable {
    # Install requested packages
    home.packages = [
      pkgs.nomacs
      mayoCustom
      pkgs.kdePackages.okular
    ];

    # Setup terminal exec default terminal and TERMINAL env var
    xdg.terminal-exec = {
      enable = true;
      settings = {
        default = ["kitty.desktop"];
      };
    };

    home.sessionVariables = {
      TERMINAL = "kitty";
    };

    xdg.configFile."mimeapps.list".force = true;

    # Configure default applications
    xdg.mimeApps = {
      enable = true;
      defaultApplications = mergedDefaults;

      # Setup VSCode as a secondary file browser option for Dolphin
      associations.added = {
        "inode/directory" = ["code.desktop"];
      };
    };
  };
}
