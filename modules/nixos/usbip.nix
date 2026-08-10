{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.usbip;
in {
  options.systemSettings.usbip = {
    enable = lib.mkEnableOption "Enable USB/IP (sharing and connecting to USB devices over IP networks)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.linuxPackages.usbip
    ];

    boot.kernelModules = [
      "usbip-host"
      "vhci-hcd"
    ];

    systemd.services.usbipd = {
      description = "USB/IP sharing daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.linuxPackages.usbip}/bin/usbipd";
        Restart = "on-failure";
      };
    };
  };
}
