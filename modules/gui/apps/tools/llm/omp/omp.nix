{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.tools.llm.omp;
  piCfg = config.features.gui.apps.tools.llm.pi;
  llmEnabled = config.features.gui.apps.tools.llm.enable;
  system = pkgs.stdenv.hostPlatform.system;
  basePackage = inputs.omp.packages.${system}.default;
in {
  options.features.gui.apps.tools.llm.omp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = llmEnabled && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs.omp = {
        url = "github:can1357/oh-my-pi";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    }

    (lib.mkIf cfg.enable {
      # omp keeps its own agent directory (~/.omp/agent): models.yml mirrors pi's
      # _models.json (local LLM gateway) as YAML, and the google-search extension
      # sits in the native auto-discovery root ~/.omp/agent/extensions. LiteLLM's
      # free-model catalog needs no shared pi extension here: omp discovers it
      # natively from the gateway pointed at by LITELLM_BASE_URL.
      home-manager.users.cloudburst = {
        imports =
          lib.optionals (inputs ? omp && inputs.omp ? homeManagerModules) [
            # Upstream home-manager module; its `{self}` parameter is filled
            # from the flake's specialArgs.
            inputs.omp.homeManagerModules.default
          ]
          ++ [
            # The model registry reads only models.yml/yaml, so ship the local
            # gateway config next to config.yml.
            {
              home.file.".omp/agent/models.yml" = {
                source = ./_models.yml;
                force = true;
              };
            }
          ];

        programs.omp = {
          enable = true;
          package = pkgs.writeShellScriptBin "omp" (
            lib.optionalString (piCfg.litellmProxy != null) ''
              export LITELLM_BASE_URL=${lib.escapeShellArg (piCfg.litellmProxy + "/v1")}
              export LITELLM_API_KEY="''${LITELLM_API_KEY:-none}"
            ''
            + lib.optionalString (piCfg.googleProxy != null) ''
              export GOOGLE_SEARCH_API_BASE=${lib.escapeShellArg piCfg.googleProxy}
            ''
            + ''
              export OMP_SKIP_SETUP=1
              export VISUAL=kwrite
              exec ${basePackage}/bin/omp "$@"
            ''
          );
          # Mirrors the live ~/.omp/agent/config.yml; omp rewrites this file at
          # runtime, but the declared values win on each switch.
          settings = {
            startup.quiet = true;
            theme.dark = "dark";
            composer = {
              shape = "rail";
              tokenRate = true;
            };
            edit.mode = "replace";
            colorBlindMode = false;
            symbolPreset = "nerd";
            modelRoles.default = "llm/qwen3.8-flash-next";
            bash.gitGuard = true;
            browser.enabled = true;
            tui.textSizing = true;
            extendedContext = true;
            astGrep.enabled = true;
            dev.autoqa = false;
            lsp = {
              diagnosticsDeduplicate = true;
              diagnosticsOnEdit = true;
            };
          };
        };

        # The google-search extension source is shared with the sibling pi module.
        home.file.".omp/agent/extensions/google-search.ts" = lib.mkIf (piCfg.googleProxy != null) {
          source = ../pi/_google-search.ts;
          force = true;
        };
      };
    })
  ];
}
