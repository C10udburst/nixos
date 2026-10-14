{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.tools.llm.pi;
  llmEnabled = config.features.gui.apps.tools.llm.enable;
in {
  imports =
    lib.optionals (inputs ? pi && inputs.pi ? nixosModules) [
      inputs.pi.nixosModules.default
    ]
    ++ lib.optionals (inputs ? pi-agent && inputs.pi-agent ? nixosModules) [
      inputs.pi-agent.nixosModules.default
    ];

  options.features.gui.apps.tools.llm.pi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = llmEnabled && true;
    };

    # Base URL of a googleaisearch2api gateway (e.g. https://google-ai-proxy.<baseDomain>).
    # null leaves the google-search extension out of the agent entirely.
    googleProxy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://google-ai-proxy.brix0.wilkins.pl.eu.org";
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        pi = {
          url = "github:lukasl-dev/pi.nix";
          inputs.nixpkgs.follows = "nixpkgs";
        };
        pi-ponytail = {
          url = "github:DietrichGebert/ponytail";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg.enable {
      home-manager.users.cloudburst = {
        home.file.".pi/agent/models.json" = {
          source = ./_models.json;
          force = true;
        };
      };

      programs.pi.coding-agent = {
        enable = true;
        extensions =
          lib.optionals (cfg.googleProxy != null) [
            ./_google-search.ts
          ]
          ++ lib.optionals (inputs ? pi-ponytail) [
            "${inputs.pi-ponytail}/pi-extension/index.js"
          ];

        skills = lib.optionals (inputs ? pi-ponytail) [
          "${inputs.pi-ponytail}/skills"
        ];
        settings = {
          theme = "dark";
          tuiMode = "regular";
          terminal = {
            showTerminalProgress = true;
          };
          enableInstallTelemetry = false;
          defaultProjectTrust = "always";
        };
      };
    })

    # Tokenless gateway behind Sablier; the tool waits out a cold start on its own,
    # so no token is configured here.
    (lib.mkIf (cfg.enable && cfg.googleProxy != null) {
      programs.pi.coding-agent.environment.GOOGLE_SEARCH_API_BASE.value = cfg.googleProxy;
    })
  ];
}
