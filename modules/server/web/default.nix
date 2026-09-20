{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web;
in {
  options.features.server.web = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.enable && false;
    };
    storage = lib.mkOption {
      type = lib.types.str;
      default = "/opt";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        users.groups.web = {};
        users.users.cloudburst.extraGroups = ["web"];

        systemd.tmpfiles.rules = [
          "d ${cfg.storage} 2775 root web - -"
          "z ${cfg.storage} 2775 root web - -"
        ];
      }
    ]
  );
}
