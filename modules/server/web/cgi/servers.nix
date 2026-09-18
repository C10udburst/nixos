{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
  webCfg = config.features.server.web;
  baseDomain = webCfg.core.baseDomain or "example.com";

  giteaEnabled = webCfg.gitea or false;
  karakeepEnabled = webCfg.karakeep or false;

  pythonWithCgi = pkgs.python3.withPackages (ps: [ps.legacy-cgi]);
in {
  config = lib.mkIf cfg.enable {
    age.secrets = lib.mkMerge [
      (lib.mkIf giteaEnabled {
        gitea-env = {
          file = ../../../../secrets/gitea-env.age;
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
      })
      (lib.mkIf karakeepEnabled {
        karakeep-env = {
          file = ../../../../secrets/karakeep-env.age;
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
      })
    ];

    features.server.web.cgi.scripts = lib.mkMerge [
      (lib.mkIf giteaEnabled {
        git_mirror.script = pkgs.writeShellScript "git_mirror" ''
          export GITEA_BASE_URL="https://git.${baseDomain}"
          if [ -f "${config.age.secrets.gitea-env.path}" ]; then
            set -a
            source "${config.age.secrets.gitea-env.path}"
            set +a
          fi
          exec ${pythonWithCgi}/bin/python3 ${./_scripts/git_mirror.py} "$@"
        '';
      })
      (lib.mkIf karakeepEnabled {
        karakeep_add.script = pkgs.writeShellScript "karakeep_add" ''
          export KARAKEEP_WAKE_URL="https://bookmarks.${baseDomain}"
          export KARAKEEP_BASE="http://127.0.0.1:3080"
          export KARAKEEP_REDIRECT_AFTER="https://bookmarks.${baseDomain}/"
          if [ -f "${config.age.secrets.karakeep-env.path}" ]; then
            set -a
            source "${config.age.secrets.karakeep-env.path}"
            set +a
          fi
          exec ${pythonWithCgi}/bin/python3 ${./_scripts/karakeep_add.py} "$@"
        '';
      })
    ];
  };
}
