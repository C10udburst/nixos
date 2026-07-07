{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.displayManager.sddm;

  renderUtils = import ../../render-template.nix {inherit pkgs config lib;};
  renderJinja2 = renderUtils.renderJinja2;
  cleanColors = renderUtils.cleanColors;

  templateData =
    cleanColors
    // {
      font = config.stylix.fonts.sansSerif.name or "JetBrainsMono Nerd Font";
      background_image = config.stylix.image;
    };

  renderedConfig = renderJinja2 "theme.conf" ./theme.conf.j2 templateData;

  sddm-eucalyptus-drop-src = pkgs.fetchFromGitLab {
    domain = "gitlab.com";
    owner = "Matt.Jolly";
    repo = "sddm-eucalyptus-drop";
    rev = "v2.0.0";
    sha256 = "sha256-wq6V3UOHteT6CsHyc7+KqclRMgyDXjajcQrX/y+rkA0=";
  };

  sddm-eucalyptus-drop-theme = pkgs.stdenv.mkDerivation {
    name = "sddm-eucalyptus-drop-templated";
    src = sddm-eucalyptus-drop-src;
    nativeBuildInputs = [pkgs.coreutils];
    installPhase = ''
      mkdir -p $out/share/sddm/themes/eucalyptus-drop
      cp -r * $out/share/sddm/themes/eucalyptus-drop/
      cp -f ${renderedConfig} $out/share/sddm/themes/eucalyptus-drop/theme.conf
    '';
  };
in {
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm = {
      theme = "eucalyptus-drop";
      extraPackages = [
        sddm-eucalyptus-drop-theme
        pkgs.kdePackages.qtdeclarative
        pkgs.kdePackages.qtsvg
        pkgs.kdePackages.qt5compat
      ];
    };
  };
}
