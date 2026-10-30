{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.nettools;
  hasWireshark = config.features.gui.apps.tools.net;
in {
  options.features.shell.utils.nettools = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.utils.enable && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs;
      [
        netcat-gnu
        nmap
        dnsutils
        traceroute
        nettools
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

    programs.wireshark = {
      enable = true;
      package =
        if hasWireshark
        then pkgs.wireshark
        else pkgs.wireshark-cli;
    };
  };
}
