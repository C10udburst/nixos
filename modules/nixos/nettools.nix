{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.nettools;
in {
  options.systemSettings.nettools = {
    enable = lib.mkEnableOption "Enable network tools (netcat, nmap, etc.)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
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
      inputs.tailcat.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    programs.wireshark.enable = true;
  };
}
