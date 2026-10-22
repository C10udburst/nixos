{
  config,
  lib,
  pkgs,
  ...
}: let
  vpnEnabled = config.features.services.vpn.enable;
  cfg = config.features.services.vpn.openvpn;
in {
  options.features.services.vpn.openvpn = lib.mkOption {
    type = lib.types.bool;
    default = vpnEnabled && false;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [
      pkgs.openvpn
      pkgs.update-systemd-resolved
    ];

    networking.networkmanager.plugins = [
      pkgs.networkmanager-openvpn
    ];
  };
}
