{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.associations;
  toolsEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable;
  isSlow = config.features.core.hardware.slow or false;
  isVscode = config.features.gui.apps.editors.vscode or false;
  isWine = config.features.compat.wine or false;

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

  harunaMimes = lib.filterAttrs (
    name: _: lib.hasPrefix "video/" name || lib.hasPrefix "audio/" name
  ) (associatePackage pkgs.haruna);
  nomacsMimes = lib.filterAttrs (name: _: lib.hasPrefix "image/" name) (associatePackage pkgs.nomacs);
  mayoMimes =
    if (!isSlow && cfg.mayo)
    then (associatePackage mayoCustom)
    else {};

  braveMimes = {
    "text/html" = ["brave-browser.desktop"];
    "text/xml" = ["brave-browser.desktop"];
    "application/xhtml+xml" = ["brave-browser.desktop"];
    "application/x-mimearchive" = ["brave-browser.desktop"];
    "x-scheme-handler/http" = ["brave-browser.desktop"];
    "x-scheme-handler/https" = ["brave-browser.desktop"];
    "x-scheme-handler/about" = ["brave-browser.desktop"];
    "x-scheme-handler/unknown" = ["brave-browser.desktop"];
    "x-scheme-handler/mailto" = ["brave-browser.desktop"];
  };

  dolphinMimes = {
    "inode/directory" = ["org.kde.dolphin.desktop"];
    "application/zip" = ["org.kde.dolphin.desktop"];
  };

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

  kdeConnectMimes = {
    "x-scheme-handler/tel" = ["org.kde.kdeconnect.handler.desktop"];
    "x-scheme-handler/sms" = ["org.kde.kdeconnect.handler.desktop"];
  };

  okularMimes = lib.filterAttrs (
    name: value:
      !(builtins.any (
          desktopFile:
            lib.hasSuffix "tiff.desktop" desktopFile
            || lib.hasSuffix "txt.desktop" desktopFile
            || lib.hasSuffix "md.desktop" desktopFile
        )
        value)
      && name != "image/tiff"
  ) (associatePackage pkgs.kdePackages.okular);

  wineMimes = {
    "application/x-ms-dos-executable" = ["wine.desktop"];
    "application/x-msi" = ["wine.desktop"];
    "application/x-ms-shortcut" = ["wine.desktop"];
    "application/x-bat" = ["wine.desktop"];
  };

  mergedDefaults = lib.foldl' lib.recursiveUpdate {} (
    [
      braveMimes
      dolphinMimes
      kdeConnectMimes
    ]
    ++ lib.optionals cfg.haruna [harunaMimes]
    ++ lib.optionals cfg.nomacs [nomacsMimes]
    ++ lib.optionals cfg.okular [okularMimes]
    ++ lib.optionals (!isSlow && cfg.mayo) [mayoMimes]
    ++ lib.optionals isVscode [vscodeMimes]
    ++ lib.optionals isWine [wineMimes]
  );
in {
  options.features.gui.apps.tools.associations = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    mayo = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    nomacs = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    haruna = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    okular = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf (toolsEnabled && cfg.enable) {
    home-manager.users.cloudburst = {
      home.packages =
        lib.optionals cfg.nomacs [pkgs.nomacs]
        ++ lib.optionals cfg.okular [pkgs.kdePackages.okular]
        ++ lib.optionals cfg.haruna [pkgs.haruna]
        ++ lib.optionals (!isSlow && cfg.mayo) [mayoCustom];

      home.file.".local/share/mime/packages/step.xml".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
          <mime-type type="model/step">
            <comment>STEP 3D Model</comment>
            <glob-deleteall/>
            <glob pattern="*.step"/>
            <glob pattern="*.stp"/>
          </mime-type>
        </mime-info>
      '';

      xdg.terminal-exec = {
        enable = true;
        settings = {
          default = ["org.kde.konsole.desktop"];
        };
      };

      home.sessionVariables = {
        TERMINAL = "konsole";
      };

      xdg.configFile."mimeapps.list".force = true;

      xdg.mimeApps = {
        enable = true;
        defaultApplications = mergedDefaults;
        associations.added = lib.optionalAttrs isVscode {
          "inode/directory" = ["code.desktop"];
        };
      };
    };
  };
}
