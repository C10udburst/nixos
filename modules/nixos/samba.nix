{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.samba;
in {
  options.systemSettings.samba = {
    enable = lib.mkEnableOption "Enable Samba file sharing service";
    path = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to the directory to share via Samba";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.path != "") {
    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "smbnix";
          "netbios name" = "smbnix";
          "security" = "user";
          "guest account" = "nobody";
          "map to guest" = "bad user";
        };
        "dane" = {
          "path" = cfg.path;
          "browseable" = "yes";
          "guest ok" = "no";
          "read only" = "no";
          "valid users" = config.hostSettings.username or "cloudburst";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = config.hostSettings.username or "cloudburst";
        };
      };
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}
