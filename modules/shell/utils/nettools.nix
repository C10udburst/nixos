{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.nettools;
in {
  options.features.shell.utils.nettools = lib.mkOption {
    type = lib.types.bool;
    default =
      if (config.features.shell.enable && config.features.shell.utils.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.utils.enable && cfg) {
    environment.systemPackages = with pkgs;
      [
        remmina
        netcat-gnu
        nmap
        dnsutils
        traceroute
        nettools
        wireshark
        websocat
        lsof
        wakeonlan
        inetutils
        wirelesstools
        socat
      ]
      ++ lib.optionals (inputs ? tailcat && inputs.tailcat ? packages && inputs.tailcat.packages ? ${pkgs.stdenv.hostPlatform.system}) [
        inputs.tailcat.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

    programs.wireshark.enable = true;
  };
}
