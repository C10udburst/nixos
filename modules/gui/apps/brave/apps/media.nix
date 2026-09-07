{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave.apps.media;
  braveEnabled = config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.brave.enable && config.features.gui.apps.brave.apps.enable;
  icons = inputs.webicons.packages.${pkgs.system} or {};
  mkWebApp = import ../_mkwebapp.nix {inherit lib pkgs;};
in {
  options.features.gui.apps.brave.apps.media = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (braveEnabled && cfg) {
    environment.systemPackages = [
      (mkWebApp {
        name = "Immich Photos";
        url = "http://go/b/photos";
        icon = icons.immich or "";
        size = "1240,760";
        categories = [
          "Graphics"
          "Photography"
        ];
      })
      (mkWebApp {
        name = "Spotify";
        url = "https://open.spotify.com";
        icon = icons.spotify or "";
        size = "1200,800";
        categories = [
          "AudioVideo"
          "Audio"
          "Music"
        ];
      })
      (mkWebApp {
        name = "YouTube Music";
        url = "https://music.youtube.com";
        icon = icons.youtube-music or "";
        size = "1200,800";
        categories = [
          "AudioVideo"
          "Audio"
          "Music"
        ];
      })
    ];
  };
}
