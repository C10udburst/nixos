{
  config,
  lib,
  ...
}: let
  cfg = config.systemSettings.flatpak;
in {
  options.systemSettings.flatpak = {
    enable = lib.mkEnableOption "Enable flatpak and declarative flatpaks";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    services.flatpak.uninstallUnmanaged = true;

    services.flatpak.remotes = lib.mkDefault [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    services.flatpak.packages = [
      "org.jdownloader.JDownloader"
    ];
  };
}
