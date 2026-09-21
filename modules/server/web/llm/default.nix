{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.llm;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ../_webService.nix {inherit config lib pkgs;};
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.pyyaml
  ]);
in {
  options.features.server.web.llm = lib.mkOption {
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
        suspend = "litellm.service";
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
          extraGroups = ["web"];
        };
        users.groups.litellm = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/litellm 2750 litellm web - -"
        ];

        systemd.services.litellm-config = {
          description = "Generate LiteLLM configuration";
          wantedBy = ["litellm.service"];
          before = ["litellm.service"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            User = "litellm";
            Group = "litellm";
            WorkingDirectory = "${storage}/litellm";
            ExecStart = "${pythonWithDeps}/bin/python3 ${./_config.py} ${config.age.secrets.litellm.path} ${storage}/litellm/config.yaml";
          };
        };

        systemd.services.litellm = {
          description = "LiteLLM Proxy Service";
          wantedBy = ["multi-user.target"];
          wants = [
            "network-online.target"
            "litellm-config.service"
          ];
          after = [
            "network-online.target"
            "litellm-config.service"
          ];
          serviceConfig = {
            User = "litellm";
            Group = "litellm";
            WorkingDirectory = "${storage}/litellm";
            ExecStart = "${pkgs.litellm}/bin/litellm --config ${storage}/litellm/config.yaml --port 4000 --host 127.0.0.1";
            Restart = "on-failure";
            RestartSec = "5s";
            Environment = [
              "HOME=${storage}/litellm"
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
