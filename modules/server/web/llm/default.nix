{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.server.web.llm.enable;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ../_webService.nix { inherit config lib pkgs; };
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.pyyaml
  ]);
in
{
  options.features.server.web.llm.enable = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "llm";
        aliases = [
          "litellm"
        ];
        port = 4000;
        cors = true;
      })
      {
        age.secrets.litellm = {
          file = ../../../../secrets/litellm.age;
          owner = "litellm";
          group = "web";
          mode = "0400";
        };

        users.users.litellm = {
          isSystemUser = true;
          group = "litellm";
          home = "${storage}/litellm";
          extraGroups = [ "web" ];
        };
        users.groups.litellm = { };

        systemd.tmpfiles.rules = [
          "d ${storage}/litellm 2750 litellm web - -"
        ];

        systemd.services.litellm-config = {
          description = "Generate LiteLLM configuration";
          wantedBy = [ "litellm.service" ];
          before = [ "litellm.service" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          restartTriggers = [ ./_config ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "litellm";
            Group = "litellm";
            WorkingDirectory = "${storage}/litellm";
            ExecStart = "${pythonWithDeps}/bin/python3 ${./_config}/main.py ${config.age.secrets.litellm.path} ${storage}/litellm/config.yaml";
          };
        };

        # Path units can only start units, so bounce the generator through a
        # throwaway oneshot: restart forces the oneshot to re-run and restarts
        # the proxy so it picks up the regenerated model_list.
        systemd.services.litellm-refresh = {
          description = "Regenerate LiteLLM configuration and reload the proxy";
          after = [
            "litellm.service"
            "litellm-config.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl restart litellm-config.service litellm.service";
          };
        };

        systemd.paths.litellm-config = {
          description = "Watch LiteLLM secrets for changes";
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathChanged = [ config.age.secrets.litellm.path ];
            Unit = "litellm-refresh.service";
          };
        };

        systemd.services.litellm = {
          description = "LiteLLM Proxy Service";
          wantedBy = [ "multi-user.target" ];
          wants = [
            "network-online.target"
            "litellm-config.service"
          ];
          after = [
            "network-online.target"
            "litellm-config.service"
          ];
          restartTriggers = [ ./_config ];
          serviceConfig = {
            User = "litellm";
            Group = "litellm";
            WorkingDirectory = "${storage}/litellm";
            ExecStart = "${pkgs.litellm}/bin/litellm --config ${storage}/litellm/config.yaml --port 4000 --host 127.0.0.1";
            Restart = "on-failure";
            RestartSec = "5s";
            Environment = [
              "HOME=${storage}/litellm"
              "LITELLM_CORS_ORIGINS=*"
              "LITELLM_CORS_ALLOW_CREDENTIALS=true"
            ];
          };
          preStart = ''
            if [ ! -f "${storage}/litellm/config.yaml" ]; then
              echo "model_list: []" > "${storage}/litellm/config.yaml"
            fi
          '';
        };
      }
    ]
  );
}
