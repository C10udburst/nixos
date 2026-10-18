{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.gitea.backup;
  giteaCfg = config.features.server.web.gitea;
  storage = config.features.server.web.storage;

  targetSubmodule = lib.types.submodule {
    options = {
      user = lib.mkOption {
        type = lib.types.str;
      };
      types = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "private"
            "public"
            "fork"
          ]
        );
        default = [
          "private"
          "public"
          "fork"
        ];
      };
      filter = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["*"];
      };
    };
  };

  backupConfigData =
    if cfg.targets != []
    then cfg.targets
    else cfg.settings;

  generatedConfigFile = pkgs.writeText "gitea-github-backup.json" (builtins.toJSON backupConfigData);
  activeConfigFile =
    if cfg.configFile != null
    then cfg.configFile
    else generatedConfigFile;

  backupScript = ./_github_backup.py;

  cliWrapper = pkgs.writeShellScriptBin "gitea-github-backup" ''
    exec ${pkgs.python3}/bin/python3 ${backupScript} \
      --config "''${1:-${activeConfigFile}}" \
      --gitea-url "${cfg.giteaUrl}" \
      --gitea-bin "${config.services.gitea.package}/bin/gitea" \
      --gitea-config "${storage}/gitea/custom/conf/app.ini" \
      --gitea-work-dir "${storage}/gitea" \
      ${lib.optionalString (cfg.giteaTokenFile != null) "--gitea-token-file ${cfg.giteaTokenFile}"} \
      ${lib.optionalString (cfg.githubTokenFile != null) "--github-token-file ${cfg.githubTokenFile}"} \
      "$@"
  '';
in {
  options.features.server.web.gitea.backup = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = giteaCfg.enable && true;
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
    };
    targets = lib.mkOption {
      type = lib.types.listOf targetSubmodule;
      default = [
        {
          user = "C10udburst";
          types = [
            "public"
            "private"
            # "fork"
          ];
          filter = ["*"];
        }
      ];
    };
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
    };
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };
    giteaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3000";
    };
    giteaTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };
    githubTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default =
        if config.age.secrets ? github-token
        then config.age.secrets.github-token.path
        else null;
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cliWrapper
    ];

    systemd.services.gitea-github-backup = {
      wantedBy = [];
      startAt = cfg.interval;
      after = [
        "network-online.target"
        "gitea.service"
      ];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "gitea";
        Group = "gitea";
        SupplementaryGroups = [
          "wheel"
          "web"
        ];
        ExecStart = "${pkgs.python3}/bin/python3 ${backupScript} --config ${activeConfigFile} --gitea-url ${cfg.giteaUrl} --gitea-bin ${config.services.gitea.package}/bin/gitea --gitea-config ${storage}/gitea/custom/conf/app.ini --gitea-work-dir ${storage}/gitea ${
          lib.optionalString (cfg.giteaTokenFile != null) "--gitea-token-file ${cfg.giteaTokenFile}"
        } ${lib.optionalString (cfg.githubTokenFile != null) "--github-token-file ${cfg.githubTokenFile}"}";
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
      };
    };
  };
}
