{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.media.gimp;

  # Interpreter used by the bundled GIMP Python-Fu plug-ins (pygobject enabled,
  # the same environment GIMP hardcodes for its own python scripts).
  gimpPython = pkgs.python3.withPackages (ps: with ps; [pygobject3]);

  aiScript = pkgs.replaceVars ./_gimp-ai.py {
    aiInterpreter = "${gimpPython}/bin/python3";
    aiBackendUrl = cfg.backendUrl;
  };

  # Installed into GIMP's plug-ins tree so `gimp3-with-plugins` merges it and
  # the procedures show up under Filters > AI.
  #
  # GIMP 3.0 only ever considers `<plug-ins>/<dir>/<dir>[.ext]`: the plug-in
  # manager scans each subdirectory for an executable whose name (minus the
  # extension) matches the directory name itself, and silently ignores anything
  # else (see gimp_plug_in_manager_search_directory). Hence directory and file
  # must share the `gimp-ai` stem.
  aiPlugin = pkgs.stdenv.mkDerivation {
    pname = "gimp-ai-plugin";
    version = "1.0";
    dontConfigure = true;
    buildCommand = ''
      mkdir -p "$out/${pkgs.gimp3.passthru.targetPluginDir}/gimp-ai"
      install -m 0755 ${aiScript} "$out/${pkgs.gimp3.passthru.targetPluginDir}/gimp-ai/gimp-ai.py"
    '';
  };
in {
  options.features.gui.apps.editors.media.gimp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.apps.editors.media.enable && true;
    };

    backendUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://evo-x2.brix0.wilkins.pl.eu.org/";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.gimp3-with-plugins.override {
        plugins = with pkgs.gimp3Plugins;
          [resynthesizer]
          ++ [aiPlugin];
      })
    ];
  };
}
