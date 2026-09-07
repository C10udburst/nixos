{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.services.usbip;
in {
  options.features.services.usbip = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.services.enable && cfg) {
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
