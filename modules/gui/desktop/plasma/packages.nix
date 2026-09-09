{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.desktop.plasma;
in {
  options.features.gui.desktop.plasma.packages = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable && true;
  };

  config = lib.mkIf cfg.packages {
    environment.systemPackages = with pkgs; [
      kdePackages.plasma-systemmonitor
      kdePackages.ksystemlog
      kdePackages.kclock
      kdePackages.partitionmanager
      kdePackages.kdeconnect-kde
      kdePackages.kde-cli-tools
      kdePackages.kfind
    ];

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      discover
      plasma-browser-integration
      khelpcenter
      gwenview
      qrca
      kwallet
      kwallet-pam
      kwalletmanager
    ];
  };
}
