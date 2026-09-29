{
  config,
  lib,
  pkgs,
  inputs,
  helpers ? null,
  ...
}: let
  cfg = config.features.gui.greeter;
  greeterEnabled = config.features.gui.enable && cfg.enable;
  hasAutologin = (cfg.autologin or null) != null && (cfg.autologin or false) != false;

  stylixEnabled = config.stylix.enable or false;
  h =
    if helpers != null
    then helpers
    else (import ../../../../lib {inherit config lib pkgs;});

  everforestColors = {
    base00 = "2b3339";
    base01 = "323c41";
    base02 = "3a464c";
    base03 = "4f5b58";
    base04 = "9da9a0";
    base05 = "d3c6aa";
    base06 = "e4e1cd";
    base07 = "fdf6e3";
    base08 = "e67e80";
    base09 = "e69875";
    base0A = "dbbc7f";
    base0B = "a7c080";
    base0C = "83c092";
    base0D = "7fbbb3";
    base0E = "d699b6";
    base0F = "9fbbac";
  };

  colors =
    if stylixEnabled
    then h.cleanColors
    else everforestColors;

  fontFamily =
    if stylixEnabled && (config.stylix.fonts.sansSerif.name or null) != null
    then config.stylix.fonts.sansSerif.name
    else "RedHatDisplay";

  renderedConfig = h.render "stylix.conf" ./_stylix.conf.j2 (colors
    // {
      inherit fontFamily;
    });

  silentsddmPackage =
    if inputs ? silentsddm && inputs.silentsddm ? packages
    then inputs.silentsddm.packages.${pkgs.stdenv.hostPlatform.system}.default or null
    else null;

  themePkg =
    if silentsddmPackage != null
    then
      silentsddmPackage.overrideAttrs (old: {
        installPhase =
          (old.installPhase or "")
          + ''
            chmod +w $out/share/sddm/themes/silent/metadata.desktop
            substituteInPlace $out/share/sddm/themes/silent/metadata.desktop \
              --replace-warn configs/default.conf configs/stylix.conf
            chmod +w $out/share/sddm/themes/silent/configs
            cp -f ${renderedConfig} $out/share/sddm/themes/silent/configs/stylix.conf
            chmod +w $out/share/sddm/themes/silent/icons/sessions
            cp -f ${./_driftwm.svg} $out/share/sddm/themes/silent/icons/sessions/driftwm.svg
          '';
      })
    else null;

  silentsddmFonts =
    if inputs ? silentsddm
    then pkgs.callPackage "${inputs.silentsddm}/nix/fonts.nix" {}
    else null;
in {
  options.features.gui.greeter.sddm = lib.mkOption {
    type = lib.types.bool;
    default = greeterEnabled && !hasAutologin && !(cfg.regreet or false);
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        silentsddm = {
          url = "github:uiriansan/SilentSDDM";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf (cfg.enable && cfg.sddm && !hasAutologin) {
      environment.systemPackages = lib.optional (themePkg != null) themePkg;

      fonts.packages = lib.optional (silentsddmFonts != null) silentsddmFonts;

      services.displayManager.sddm = {
        enable = true;
        wayland.enable = lib.mkDefault true;
        theme = lib.mkForce "silent";
        extraPackages = [
          pkgs.kdePackages.qtmultimedia
          pkgs.kdePackages.qtsvg
          pkgs.kdePackages.qtvirtualkeyboard
          pkgs.kdePackages.qtimageformats
        ];
        settings = lib.mkIf (themePkg != null) {
          General = {
            GreeterEnvironment = "QML2_IMPORT_PATH=${themePkg}/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard";
            InputMethod = "qtvirtualkeyboard";
          };
        };
      };

      security.pam.services.sddm.enableGnomeKeyring = true;
    })
  ];
}
