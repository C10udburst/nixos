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
  # Extension groups and gateway URLs, shared with the other pi agents through
  # the llm/pi/extensions/default.nix module.
  ext = piCfg.extensions;
  # This agent's prompt: the organizer template, and none of the sections that
  # belong to a coding agent or to an extension this group does not load.
  prompt = piCfg.prompt;
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
          # The pi group: the machine lease and the LiteLLM catalog, same as the
          # terminal agent minus the web search tool. No web search, so the prompt
          # below must not mention it.
          extensions = ext.piExtensions;
          environment =
            {
              # TODO: can i use "~" here instead of hardcoding the path?
              PI_CODING_AGENT_DIR.value = "/home/cloudburst/.pi/organizeer";
            }
            // lib.mapAttrs (_: value: {inherit value;}) ext.environment;
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

      # The agent directory this package is pointed at, so this is its whole
      # system prompt: task management only, no code, no nix, no search.
      home.file.".pi/organizeer/SYSTEM.md" = lib.mkIf prompt.enable {
        source = prompt.shared.mkSystemPrompt {
          name = "organizeer";
          template = "organizeer";
          google = false;
          comma = false;
          nix = false;
        };
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
