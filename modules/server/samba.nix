{
  config,
  lib,
  ...
}: let
  serverEnabled = config.features.server.enable;
  cfg = config.features.server.samba;

  allPaths =
    (lib.optionals (cfg.path != "") [cfg.path])
    ++ cfg.paths;
in {
  options.features.server.samba = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    path = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkIf (serverEnabled && cfg.enable && allPaths != []) {
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
          "path" = lib.head allPaths;
          "browseable" = "yes";
          "guest ok" = "no";
          "read only" = "no";
          "valid users" = "cloudburst";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "cloudburst";
        };
      };
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}
