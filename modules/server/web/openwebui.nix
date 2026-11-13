{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.openwebui;
  storage = config.features.server.web.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  autheliaEnabled = config.features.server.web.authelia.enable or false;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  port = 8090;
  # EVO-X2 LLM gateway (same upstream as web.evo-x2)
  gatewayUrl = "http://llm.wilkins.pl.eu.org:8080/v1";
in {
  options.features.server.web.openwebui = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "chat";
        aliases = [
          "openwebui"
          "open-webui"
          "owui"
        ];
        inherit port;
        suspend = "open-webui.service";
        cors = true;
      })
      (lib.mkIf autheliaEnabled {
        features.server.web.authelia._oidcClients = [
          (webHelper.mkOidcClient {
            id = "openwebui";
            name = "Open WebUI";
            redirectUris = [
              "https://chat.${baseDomain}/oauth/oidc/callback"
            ];
          })
        ];
      })
      {
        users.users.openwebui = {
          isSystemUser = true;
          group = "openwebui";
          home = "${storage}/openwebui";
        };
        users.groups.openwebui = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/openwebui 2750 openwebui web - -"
          "z ${storage}/openwebui 2750 openwebui web - -"
        ];

        age.secrets.openwebui-env = {
          file = ../../../secrets/openwebui-env.age;
          owner = "openwebui";
          group = "openwebui";
          mode = "0400";
        };

        services.open-webui = {
          enable = true;
          host = "127.0.0.1";
          inherit port;
          stateDir = "${storage}/openwebui";
          environmentFile = config.age.secrets.openwebui-env.path;
          environment =
            {
              SCARF_NO_ANALYTICS = "True";
              DO_NOT_TRACK = "True";
              ANONYMIZED_TELEMETRY = "False";
              WEBUI_URL = "https://chat.${baseDomain}";
              # OpenAI-compatible endpoint only: the EVO-X2 gateway serves the
              # model list and completions for chat.
              ENABLE_OLLAMA_API = "False";
              OPENAI_API_BASE_URL = gatewayUrl;
              # Gateway is unauthenticated; a placeholder key satisfies the
              # OpenAI client requirement (same convention as the pi/omp configs).
              OPENAI_API_KEY = "none";
              # RAG embeddings: EmbeddingGemma 300M on the gateway (768-dim).
              RAG_EMBEDDING_ENGINE = "openai";
              RAG_EMBEDDING_MODEL = "embed-gemma:300m";
              RAG_OPENAI_API_BASE_URL = gatewayUrl;
              RAG_OPENAI_API_KEY = "none";
              # Voice input: faster-whisper turbo via the gateway's ASR backend.
              AUDIO_STT_ENGINE = "openai";
              AUDIO_STT_MODEL = "whisper-v3:turbo";
              AUDIO_STT_OPENAI_API_BASE_URL = gatewayUrl;
              AUDIO_STT_OPENAI_API_KEY = "none";
            }
            // lib.optionalAttrs autheliaEnabled {
              OAUTH_CLIENT_ID = "openwebui";
              OPENID_PROVIDER_URL = "https://auth.${baseDomain}/.well-known/openid-configuration";
              OPENID_REDIRECT_URI = "https://chat.${baseDomain}/oauth/oidc/callback";
              OAUTH_PROVIDER_NAME = "Authelia";
              OAUTH_SCOPES = "openid email profile";
              ENABLE_OAUTH_SIGNUP = "True";
              OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
            };
        };

        # The upstream module assumes DynamicUser, which cannot own a persistent
        # directory on the storage mount; run under a named service account instead.
        systemd.services.open-webui.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "openwebui";
          Group = "openwebui";
          SupplementaryGroups = ["web"];
        };
      }
    ]
  );
}
