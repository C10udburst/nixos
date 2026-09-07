{
  config,
  lib,
  ...
}: let
  serverEnabled = config.features.server.enable;
  cfg = config.features.server.samba;

  shareEntries = lib.listToAttrs (map (p: {
      name = baseNameOf p;
      value = {
        path = p;
        browseable = "yes";
        "guest ok" = "no";
        "read only" = "no";
        "valid users" = "cloudburst";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "cloudburst";
      };
    })
    cfg.paths);
in {
  options.features.server.samba = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.enable && false;
    };
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkIf (cfg.enable && cfg.paths != []) {
    services.samba = {
      enable = true;
      openFirewall = true;
      settings =
        {
          global = {
            "workgroup" = "WORKGROUP";
            "server string" = "smbnix";
            "netbios name" = "smbnix";
            "security" = "user";
            "guest account" = "nobody";
            "map to guest" = "bad user";
          };
        }
        // shareEntries;
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}
