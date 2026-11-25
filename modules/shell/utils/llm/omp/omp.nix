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
  evoX2 = import ../_evo-x2.nix;
  # Extension groups and gateway URLs, shared with the pi agents through the
  # llm/pi/extensions/default.nix module. omp takes the shared machine lease plus
  # the web search tool: it discovers LiteLLM's free-model catalog natively
  # through LITELLM_BASE_URL, and its prompt carries no pi <docs> section for
  # the docs-stripping extension to remove.
  ext = piCfg.extensions;
  ompExtensions =
    ext.baseExtensions ++ lib.optional (ext.googleUrl != null) ext.shared.googleSearch;
  # ~/.omp/agent/extensions is an auto-discovery root, and the `_` prefix that
  # keeps the sources out of import-tree is dropped on the way in.
  ompExtensionFiles = lib.listToAttrs (
    map (path: {
      name = ".omp/agent/extensions/${lib.removePrefix "_" (baseNameOf path)}";
      value = {
        source = path;
        force = true;
      };
    })
    ompExtensions
  );
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
      # from the shared llm/_evo-x2.nix catalog, and the extensions it loads sit
      # in the native auto-discovery root ~/.omp/agent/extensions.
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
            # omp names the LiteLLM gateway differently from the pi extensions.
            lib.optionalString (ext.litellmUrl != null) ''
              export LITELLM_BASE_URL=${lib.escapeShellArg (ext.litellmUrl + "/v1")}
              export LITELLM_API_KEY="''${LITELLM_API_KEY:-none}"
            ''
            + lib.optionalString (ext.googleUrl != null) ''
              export GOOGLE_SEARCH_API_BASE=${lib.escapeShellArg ext.googleUrl}
            ''
            + lib.optionalString (ext.reservationsUrl != null) ''
              export EVO_X2_RESERVATIONS_URL=${lib.escapeShellArg ext.reservationsUrl}
              export EVO_X2_QUEUE_DOMAIN=${lib.escapeShellArg ext.shared.gatewayDomain}
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

        home.file = ompExtensionFiles;
      };
    })
  ];
}
