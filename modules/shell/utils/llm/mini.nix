{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.llm.mini;

  llmRegistry = import ./_evo-x2.nix;

  litellmModelRegistryFile = (pkgs.formats.json {}).generate "evo-x2-litellm-registry.json" (
    builtins.listToAttrs (
      map (m: {
        name = "openai/${m.id}";
        value = {
          max_tokens = m.maxTokens;
          max_input_tokens = m.contextWindow;
          max_output_tokens = m.maxTokens;
          input_cost_per_token = 0.0;
          output_cost_per_token = 0.0;
          litellm_provider = "openai";
          mode = "chat";
          supports_vision = builtins.elem "image" (m.input or []);
          supports_reasoning = m ? effortMap;
        };
      })
      llmRegistry.models
    )
  );

  yamlFormat = pkgs.formats.yaml {};

  # Generate a deterministic YAML config file in the Nix store per model ID
  modelConfigsDir = pkgs.linkFarm "mini-swe-agent-model-configs" (
    map (m: {
      name = "${m.id}.yaml";
      path = yamlFormat.generate "mini-${m.id}.yaml" {
        model = {
          model_name = "openai/${m.id}";
          litellm_model_registry = "${litellmModelRegistryFile}";
          cost_tracking = "ignore_errors";
          model_kwargs = {
            api_base = llmRegistry.baseUrl;
            api_key = "none";
            max_tokens = m.maxTokens;
          };
        };
      };
    })
    llmRegistry.models
  );

  python = pkgs.python3Packages;

  mini-swe-agent-unwrapped = python.buildPythonApplication {
    pname = "mini-swe-agent";
    version = "2.4.6";
    src = inputs.mini-swe-agent-src;
    pyproject = true;

    build-system = [python.setuptools];
    dependencies = with python; [
      datasets
      jinja2
      litellm
      openai
      platformdirs
      prompt-toolkit
      pydantic
      python-dotenv
      pyyaml
      requests
      rich
      tenacity
      textual
      typer
    ];

    doCheck = false;
  };

  # Wrapper script that translates `-m <id>` / `--model <id>` -> `--config /nix/store/.../<id>.yaml`
  mkMiniWrapper = binName:
    pkgs.writeShellScriptBin binName ''
      set -euo pipefail

      CONFIG_DIR="${modelConfigsDir}"
      ARGS=()
      HAS_MODEL=0

      resolve_model() {
        local model_id="$1"
        local cfg_file="$CONFIG_DIR/$model_id.yaml"
        if [[ ! -f "$cfg_file" ]]; then
          echo "Error: Unknown model '$model_id'." >&2
          echo "Available models:" >&2
          ls -1 "$CONFIG_DIR" | sed 's/\.yaml$//' | sed 's/^/  - /' >&2
          exit 1
        fi
        ARGS+=(-c mini.yaml -c "$cfg_file")
        HAS_MODEL=1
      }

      while [[ $# -gt 0 ]]; do
        case "$1" in
          -m|--model)
            if [[ $# -lt 2 ]]; then
              echo "Error: $1 requires a model ID" >&2
              exit 1
            fi
            resolve_model "$2"
            shift 2
            ;;
          -m=*|--model=*)
            resolve_model "''${1#*=}"
            shift
            ;;
          *)
            ARGS+=("$1")
            shift
            ;;
        esac
      done

      exec "${mini-swe-agent-unwrapped}/bin/${binName}" "''${ARGS[@]}"
    '';

  mini-swe-agent = pkgs.symlinkJoin {
    name = "mini-swe-agent-wrapped-${mini-swe-agent-unwrapped.version}";
    paths = [
      (mkMiniWrapper "mini")
      (mkMiniWrapper "mini-swe-agent")
      mini-swe-agent-unwrapped
    ];
  };
in {
  options.features.shell.utils.llm.mini = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.shell.utils.llm.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        mini-swe-agent-src = {
          url = "github:swe-agent/mini-swe-agent";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        mini-swe-agent
      ];
    })
  ];
}
