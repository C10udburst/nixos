# Single source of truth shared by every pi-family agent (pi, omp, pi-web):
# the gateway URLs the bundled extensions talk to, plus the extension sources
# themselves. Consumers import this file, pick the extensions they load, and
# export the matching environment variables so nothing is hardcoded elsewhere.
#
# Prefixed with `_` so import-tree skips it: this is data, not a NixOS module.
rec {
  urls = {
    # googleaisearch2api gateway (Sablier-suspended, wakes on demand).
    google = "https://google-ai-proxy.brix0.wilkins.pl.eu.org";

    # LiteLLM gateway hosting the free-model catalog.
    litellm = "https://llm.brix0.wilkins.pl.eu.org";

    # EVO-X2 gateway host; serves the /api/reservations endpoint that
    # _queue.ts reserves the shared machine through.
    reservations = "https://evo-x2.brix0.wilkins.pl.eu.org";
  };

  # Substring a model's baseUrl must contain for the evo-x2 queue logic to
  # activate; models served from anywhere else run ungated.
  gatewayDomain = "evo-x2";

  extensions = {
    googleSearch = ./_google-search.ts;
    litellm = ./_litellm.ts;
    systemPrompt = ./_system-prompt.ts;
    queue = ./_queue.ts;
  };

  # Environment the extensions above consume; consumers export what they deploy.
  environment = {
    GOOGLE_SEARCH_API_BASE = urls.google;
    LITELLM_API_BASE = urls.litellm;
    EVO_X2_RESERVATIONS_URL = urls.reservations;
    EVO_X2_QUEUE_DOMAIN = gatewayDomain;
  };
}
