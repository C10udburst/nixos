{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.editors.jetbrains;
  editorsEnabled = config.features.gui.apps.editors.enable;

  isDev = config.features.gui.dev.enable or false;
  isProgramming = isDev && (config.features.gui.dev.programming.enable or false);
  isRust = isProgramming && (config.features.gui.dev.programming.rust or false);
  isGo = isProgramming && (config.features.gui.dev.programming.go or false);
  isPython = isDev && (config.features.gui.dev.python.enable or false);
  isKotlin = isProgramming && (config.features.gui.dev.programming.kotlin or false);

  jetbra-netfilter = pkgs.stdenv.mkDerivation {
    pname = "jetbra-netfilter";
    version = "1.0.0";
    src = inputs.jetbra-netfilter;
    nativeBuildInputs = [pkgs.unzip];
    installPhase = ''
      mkdir -p $out
      if [ -d "$src/jetbra" ]; then
        cp -r $src/jetbra/* $out/
      elif [ -d "$src" ]; then
        cp -r $src/* $out/
      else
        unzip $src -d $out
        if [ -d "$out/jetbra" ]; then
          mv $out/jetbra/* $out/
          rmdir $out/jetbra
        fi
      fi
        chmod -R +w $out
        rm -f $out/README.pdf
        rm -rf $out/scripts

      for file in $out/vmoptions/*; do
        sed -i '/^\-javaagent:.*[\/\\]ja\-netfilter\.jar.*/d' "$file"
        echo "-javaagent:''${out}/ja-netfilter.jar=jetbrains" >> "$file"
      done
    '';
  };
in {
  options.features.gui.apps.editors.jetbrains = lib.mkOption {
    type = lib.types.bool;
    default = editorsEnabled && false;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        jetbra-netfilter = {
          url = "https://ipfs.filebase.io/ipns/3.jetbra.in/files/jetbra-8f6785eac5e6e7e8b20e6174dd28bb19d8da7550.zip";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages =
        lib.optionals isRust [pkgs.jetbrains.rust-rover]
        ++ lib.optionals isGo [pkgs.jetbrains.goland]
        ++ lib.optionals isPython [pkgs.jetbrains.pycharm]
        ++ lib.optionals isKotlin [pkgs.jetbrains.idea];

      home-manager.users.cloudburst = {
        home.packages = [jetbra-netfilter];
        home.sessionVariables = {
          IDEA_VM_OPTIONS = "${jetbra-netfilter}/vmoptions/idea.vmoptions";
          PYCHARM_VM_OPTIONS = "${jetbra-netfilter}/vmoptions/pycharm.vmoptions";
          RUSTROVER_VM_OPTIONS = "${jetbra-netfilter}/vmoptions/rustrover.vmoptions";
          GOLAND_VM_OPTIONS = "${jetbra-netfilter}/vmoptions/goland.vmoptions";
        };
      };
    })
  ];
}
