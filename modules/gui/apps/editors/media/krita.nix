{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.media.krita;
  mediaEnabled = config.features.gui.apps.editors.media.enable;

  kritaWrapped = pkgs.symlinkJoin {
    name = "krita-xcb";
    paths = [pkgs.krita];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm -rf $out/bin
      mkdir -p $out/bin
      for bin in ${pkgs.krita}/bin/*; do
        makeWrapper "$bin" "$out/bin/''${bin##*/}" \
          --set QT_QPA_PLATFORM "xcb"
      done
    '';
  };
in {
  options.features.gui.apps.editors.media.krita = lib.mkOption {
    type = lib.types.bool;
    default = mediaEnabled && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [kritaWrapped];
  };
}
