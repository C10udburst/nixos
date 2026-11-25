{
  config,
  lib,
  ...
}: let
  cfg = config.features.shell.utils.llm.pi.extensions;

  # The extension sources. Fixed locations, not options: they live next to this
  # module and only ever move with it. The `_` prefix keeps them out of
  # import-tree's module discovery, the `.ts` suffix keeps them out of Nix.
  systemPrompt = ./_system-prompt.ts;
  litellm = ./_litellm.ts;
  googleSearch = ./_google-search.ts;
  queue = ./_queue.ts;

  # Substring a model's baseUrl must contain for the lease logic to arm itself;
  # models served from anywhere else run ungated. Also fixed: it names the
  # gateway host rather than a deployment choice.
  gatewayDomain = "evo-x2.brix0.wilkins.pl.eu.org";
in {
  # Values shared with consumers that need one source or the gateway name on its
  # own: omp deploys files into its auto-discovery root rather than taking a
  # group wholesale, and it exports EVO_X2_QUEUE_DOMAIN straight from the module.
  # Internal options so they stay out of the host-facing feature tree.
  options.features.shell.utils.llm.pi.extensions.shared = {
    gatewayDomain = lib.mkOption {
      type = lib.types.str;
      internal = true;
    };
    googleSearch = lib.mkOption {
      type = lib.types.path;
      internal = true;
    };
  };

  options.features.shell.utils.llm.pi.extensions = {
    # Base URLs of the external gateways; a null URL leaves the matching
    # extension out of every agent that loads the group.
    litellmUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://llm.brix0.wilkins.pl.eu.org";
    };

    # A googleaisearch2api gateway, suspended behind Sablier and woken on demand.
    googleUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://google-ai-proxy.brix0.wilkins.pl.eu.org";
    };

    # The EVO-X2 host serving /api/reservations, which the /enqueue lease uses.
    reservationsUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://evo-x2.brix0.wilkins.pl.eu.org";
    };

    # ─────────────────────────────────────────────────────────────────────────────
    # Extension groups shared by every pi-family agent.
    #
    #   baseExtensions     the /enqueue machine lease; loaded by pi and omp.
    #   piExtensions       base + the docs strip + the LiteLLM catalog; loaded by
    #                      the full pi agent and the organizer pi.
    #   piAgentExtensions  pi + the web search tool; loaded by the terminal pi and
    #                      pi-web.
    #
    # omp takes `baseExtensions` plus the search tool from `shared`.
    # ─────────────────────────────────────────────────────────────────────────────
    baseExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = lib.optional (cfg.reservationsUrl != null) queue;
    };

    piExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = cfg.baseExtensions ++ [systemPrompt] ++ lib.optional (cfg.litellmUrl != null) litellm;
    };

    piAgentExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = cfg.piExtensions ++ lib.optional (cfg.googleUrl != null) googleSearch;
    };

    # The gateway URLs the deployed extensions read; every consumer exports the
    # part of this it actually loads.
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = lib.filterAttrs (_: value: value != null) {
        LITELLM_API_BASE = cfg.litellmUrl;
        GOOGLE_SEARCH_API_BASE = cfg.googleUrl;
        EVO_X2_RESERVATIONS_URL = cfg.reservationsUrl;
        EVO_X2_QUEUE_DOMAIN =
          if cfg.reservationsUrl != null
          then gatewayDomain
          else null;
      };
    };
  };

  config.features.shell.utils.llm.pi.extensions.shared = {
    inherit gatewayDomain googleSearch;
  };
}
