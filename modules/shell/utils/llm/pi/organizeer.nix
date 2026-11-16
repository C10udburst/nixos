{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.llm.pi.organizeer;
  piCfg = config.features.shell.utils.llm.pi;
  orgCfg = config.features.gui.apps.tools.organizeer;
  organizeerUrl = "https://tasks.brix0.wilkins.pl.eu.org/mcp";
  # Shared EVO-X2 gateway catalog; this agent's models.json is generated from it.
  evoX2 = import ../_evo-x2.nix;
  modelsJson = pkgs.writeText "organizeer-models.json" evoX2.piJson;
  # bun needs AVX, node runs everywhere (see the pi module)
  piPackage =
    if config.features.core.hardware.avx
    then inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent-bun
    else inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;
  organizeerAgent = inputs.pi.lib.mkCodingAgent {
    inherit pkgs;
    modules = [
      {
        pi.coding-agent = {
          package = piPackage;
          models = modelsJson;
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
            []
            ++ lib.optionals (piCfg.litellmProxy != null) [
              ./_litellm.ts
            ];
          environment =
            {
              # TODO: can i use "~" here instead of hardcoding the path?
              PI_CODING_AGENT_DIR.value = "/home/cloudburst/.pi/organizeer";
            }
            // lib.optionalAttrs (piCfg.litellmProxy != null) {
              LITELLM_API_BASE.value = piCfg.litellmProxy;
            };
        };
      }
    ];
  };
in {
  options.features.shell.utils.llm.pi.organizeer = lib.mkOption {
    type = lib.types.bool;
    default = piCfg.enable && orgCfg;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst = {
      home.packages = [
        (pkgs.writeShellScriptBin "organizeer-pi" ''
          exec ${lib.getExe organizeerAgent.package} "$@"
        '')
      ];

      home.file.".pi/organizeer/models.json" = {
        text = evoX2.piJson;
        force = true;
      };

      xdg.desktopEntries.organizeer-pi = {
        name = "Organizeer Pi";
        genericName = "Organizeer Task Agent";
        comment = "Organizeer task & to-do management agent (Pi TUI)";
        exec = "organizeer-pi";
        icon = "utilities-terminal";
        terminal = true;
        categories = [
          "Utility"
          "TerminalEmulator"
        ];
      };
    };
  };
}
