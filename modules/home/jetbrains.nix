{
  config,
  lib,
  pkgs,
  ...
}: let
  jetbra-netfilter = let
    pname = "jetbra-netfilter";
    version = "1.0.0";
    src = pkgs.fetchurl {
      url = "https://3.jetbra.in/files/jetbra-5a50fc03d68a014f893b7fc3aa465380d59f9095.zip";
      sha1 = "sha1-5a50fc03d68a014f893b7fc3aa465380d59f9095";
    };
  in
    pkgs.stdenv.mkDerivation {
      inherit pname version src;
      nativeBuildInputs = [pkgs.unzip];
      installPhase = ''
        mkdir -p $out
        unzip $src -d $out

        for file in $out/vmoptions/*; do
          sed -i '/^\-javaagent:.*[\/\\]ja\-netfilter\.jar.*/d' "$file"
          echo "-javaagent:''${out}/ja-netfilter.jar=jetbrains" >> "$file"
        done
      '';
    };

  cfg = config.homeSettings.jetbrains;
in {
  options.homeSettings.jetbrains = {
    enable = lib.mkEnableOption "Enable JetBrains IDEs (IntelliJ IDEA and PyCharm)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      jetbra-netfilter
    ];

    vmoptionsMap = {
      "IntelliJIdea2026.1" = "idea.vmoptions";
      "PyCharm2026.1" = "pycharm.vmoptions";
    };

    # iterate over the vmoptionsMap and create symlinks for each IDE
    home.file = lib.mkMerge (lib.attrsets.mapAttrs (name: vmoptions: {
        source = "${jetbra-netfilter}/vmoptions/${vmoptions}";
        target = ".config/JetBrains/${name}/${vmoptions}";
      })
      cfg.vmoptionsMap);
  };
}
