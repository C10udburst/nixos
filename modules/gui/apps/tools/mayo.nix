{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.mayo;
  toolsEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable;
  isSlow = config.features.core.hardware.slow or false;
  associatePackage = (import ../../../../lib/helpers/associations.nix {inherit lib;}).associatePackage;

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

  mayoMimes = associatePackage mayoCustom;
in {
  options.features.gui.apps.tools.mayo = lib.mkOption {
    type = lib.types.bool;
    default = !isSlow;
  };

  config = lib.mkIf (toolsEnabled && cfg && !isSlow) {
    home-manager.users.cloudburst = {
      home.packages = [mayoCustom];

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

      xdg.mimeApps.defaultApplications = mayoMimes;
    };
  };
}
