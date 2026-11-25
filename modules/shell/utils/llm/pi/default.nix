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
  # Extension groups and gateway URLs, shared with omp, the organizer pi and
  # pi-web through the llm/pi/extensions/default.nix module.
  ext = cfg.extensions;
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
        # Every extension a full pi agent loads: the machine lease, the docs
        # strip, the LiteLLM catalog and the web search tool.
        extensions = ext.piAgentExtensions;

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

    # The gateway URLs the deployed extensions read (Sabrier wakes the search
    # gateway on demand, so no token is configured for it).
    (lib.mkIf cfg.enable {
      programs.pi.coding-agent.environment =
        lib.mapAttrs (_: value: {inherit value;}) ext.environment;
    })
  ];
}
