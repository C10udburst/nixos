{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.llm.omp;
  piCfg = config.features.shell.utils.llm.pi;
  llmEnabled = config.features.shell.utils.llm.enable;
  system = pkgs.stdenv.hostPlatform.system;
  basePackage = inputs.omp.packages.${system}.default;
  # Shared EVO-X2 gateway catalog; omp gets its models.yml generated from it.
  evoX2 = import ../_evo-x2.nix;
  # Shared extension sources and gateway URLs (pi, omp and pi-web all read it).
  ext = import ../pi/_extensions.nix;
in {
  options.features.shell.utils.llm.omp = {
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
      # omp keeps its own agent directory (~/.omp/agent): models.yml is rendered
      # from the shared llm/_evo-x2.nix catalog, and the extensions shared with
      # the pi module (llm/pi/_extensions.nix) sit in the native auto-discovery
      # root ~/.omp/agent/extensions. LiteLLM's free-model catalog needs no
      # shared pi extension here: omp discovers it natively from the gateway
      # pointed at by LITELLM_BASE_URL.
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
                source = (pkgs.formats.yaml {}).generate "models.yml" evoX2.ompRegistry;
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
            + lib.optionalString (piCfg.reservationsApi != null) ''
              export EVO_X2_RESERVATIONS_URL=${lib.escapeShellArg piCfg.reservationsApi}
              export EVO_X2_QUEUE_DOMAIN=${lib.escapeShellArg ext.gatewayDomain}
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

        # Extension sources are shared with the sibling pi module via _extensions.nix.
        home.file.".omp/agent/extensions/system-prompt.ts" = {
          source = ext.extensions.systemPrompt;
          force = true;
        };
        home.file.".omp/agent/extensions/google-search.ts" = lib.mkIf (piCfg.googleProxy != null) {
          source = ext.extensions.googleSearch;
          force = true;
        };
        home.file.".omp/agent/extensions/evo-x2-queue.ts" = lib.mkIf (piCfg.reservationsApi != null) {
          source = ext.extensions.queue;
          force = true;
        };
      };
    })
  ];
}
