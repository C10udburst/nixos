{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.features.gui.apps.tools.llm.pi.organizeer;
  piCfg = config.features.gui.apps.tools.llm.pi;
  orgCfg = config.features.gui.apps.tools.organizeer;
  organizeerUrl = "https://tasks.brix0.wilkins.pl.eu.org/mcp";
  organizeerAgent = inputs.pi.lib.mkCodingAgent {
    inherit pkgs;
    modules = [
      {
        pi.coding-agent = {
          package = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent-bun;
          models = ./_models.json;
          rules = ./_organizeer-agent.md;
          settings = {
            theme = "dark";
            tuiMode = "regular";
            terminal = {
              showTerminalProgress = true;
            };
            enableInstallTelemetry = false;
            defaultProjectTrust = "always";
          };
          mcp = {
            mcpServers.organizeer = {
              type = "http";
              url = organizeerUrl;
              exposure = "direct";
            };
          };
          extensions =
            [
              "${inputs.pi-context}"
            ]
            ++ lib.optionals (piCfg.litellmProxy != null) [
              ./_litellm.ts
            ];
          environment = {
            PI_CODING_AGENT_DIR.value = "${config.home.homeDirectory}/.pi/organizeer";
          }
          // lib.optionalAttrs (piCfg.litellmProxy != null) {
            LITELLM_API_BASE.value = piCfg.litellmProxy;
          };
        };
      }
    ];
  };
in
{
  options.features.gui.apps.tools.llm.pi.organizeer = lib.mkOption {
    type = lib.types.bool;
    default = piCfg.enable && orgCfg;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst.home.packages = [
      (pkgs.writeShellScriptBin "organizeer-pi" ''
        exec ${lib.getExe organizeerAgent.package} "$@"
      '')
    ];
  };
}
