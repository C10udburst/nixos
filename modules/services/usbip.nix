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
    default = config.features.services.enable && false;
  };

  config = lib.mkIf cfg {
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
