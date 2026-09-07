{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.jetbrains;
  editorsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable;

  isDev = config.features.gui.dev.enable or false;
  isProgramming = isDev && (config.features.gui.dev.programming.enable or false);
  isRust = isProgramming && (config.features.gui.dev.programming.rust.enable or false);
  isGo = isProgramming && (config.features.gui.dev.programming.go or false);
  isPython = isDev && (config.features.gui.dev.python.enable or false);
  isKotlin = isProgramming && (config.features.gui.dev.programming.kotlin or false);

  jetbra-netfilter = let
    pname = "jetbra-netfilter";
    version = "1.0.0";
    src = pkgs.fetchurl {
      url = "https://3.jetbra.in/files/jetbra-5a50fc03d68a014f893b7fc3aa465380d59f9095.zip";
      sha1 = "5a50fc03d68a014f893b7fc3aa465380d59f9095";
    };
  in
    pkgs.stdenv.mkDerivation {
      inherit pname version src;
      nativeBuildInputs = [pkgs.unzip];
      installPhase = ''
        mkdir -p $out
        unzip $src -d $out
        mv $out/jetbra/* $out/
        rmdir $out/jetbra
        rm $out/README.pdf
        rm -rf $out/scripts

        for file in $out/vmoptions/*; do
          sed -i '/^\-javaagent:.*[\/\\]ja\-netfilter\.jar.*/d' "$file"
          echo "-javaagent:''${out}/ja-netfilter.jar=jetbrains" >> "$file"
        done
      '';
    };
in {
  options.features.gui.apps.editors.jetbrains = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf (editorsEnabled && cfg.enable) {
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
      };
    };
  };
}
