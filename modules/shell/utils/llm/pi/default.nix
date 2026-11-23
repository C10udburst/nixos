{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.llm.pi;
  llmEnabled = config.features.shell.utils.llm.enable;
  # Shared EVO-X2 gateway catalog; pi gets its models.json generated from it.
  evoX2 = import ../_evo-x2.nix;
  # Shared extension sources and gateway URLs (pi, omp and pi-web all read it).
  ext = import ./_extensions.nix;
  # The bun runtime binary requires AVX (SIGILL on `vzeroupper` pre-Haswell,
  # e.g. the Pentium 4415Y in surface). The node variant runs everywhere.
  piPackage =
    if config.features.core.hardware.avx
    then inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent-bun
    else inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;
in {
  imports =
    lib.optionals (inputs ? pi && inputs.pi ? nixosModules) [
      inputs.pi.nixosModules.default
    ]
    ++ lib.optionals (inputs ? pi-agent && inputs.pi-agent ? nixosModules) [
      inputs.pi-agent.nixosModules.default
    ];

  options.features.shell.utils.llm.pi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = llmEnabled && true;
    };

    # Base URL of a googleaisearch2api gateway (e.g. https://google-ai-proxy.<baseDomain>).
    # null leaves the google-search extension out of the agent entirely.
    googleProxy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = ext.urls.google;
    };

    # Base URL of a LiteLLM gateway (e.g. https://llm.<baseDomain>).
    # null leaves the litellm extension out of the agent entirely.
    litellmProxy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = ext.urls.litellm;
    };

    # Base URL of the EVO-X2 gateway host serving /api/reservations.
    # null leaves the /enqueue reservation extension out of the agent entirely.
    reservationsApi = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = ext.urls.reservations;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        pi = {
          url = "github:lukasl-dev/pi.nix";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      home-manager.users.cloudburst = {
        # Generated from llm/_evo-x2.nix, the single source of truth for the
        # gateway's chat models.
        home.file.".pi/agent/models.json" = {
          text = evoX2.piJson;
          force = true;
        };
      };

      programs.pi.coding-agent = {
        enable = true;
        package = piPackage;
        extensions =
          [
            ext.extensions.systemPrompt
          ]
          ++ lib.optionals (cfg.googleProxy != null) [
            ext.extensions.googleSearch
          ]
          ++ lib.optionals (cfg.litellmProxy != null) [
            ext.extensions.litellm
          ]
          ++ lib.optionals (cfg.reservationsApi != null) [
            ext.extensions.queue
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

    # LiteLLM gateway URL
    (lib.mkIf (cfg.enable && cfg.litellmProxy != null) {
      programs.pi.coding-agent.environment.LITELLM_API_BASE.value = cfg.litellmProxy;
    })

    # EVO-X2 reservations API; the /enqueue extension blocks the agent until the
    # shared machine is reserved, and only arms itself for models whose baseUrl
    # matches the gateway domain.
    (lib.mkIf (cfg.enable && cfg.reservationsApi != null) {
      programs.pi.coding-agent.environment = {
        EVO_X2_RESERVATIONS_URL.value = cfg.reservationsApi;
        EVO_X2_QUEUE_DOMAIN.value = ext.gatewayDomain;
      };
    })
  ];
}
