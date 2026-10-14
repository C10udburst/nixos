{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.googleAiProxy;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};

  # Tokenless Google-backed search gateway (googleaisearch2api). It is exposed without
  # credentials, so it binds loopback only (the app itself refuses a non-loopback bind with an
  # empty API_TOKEN) and lets the edge protect it. Sablier can suspend and lazily wake it, which
  # clients absorb by retrying while the proxy waits for the container.
  name = "google-ai-proxy";
  port = 9010;
in {
  options.features.server.web.googleAiProxy = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && false;
  };

  # Public origin of the gateway, usable by clients on any host (the base domain already points at
  # the machine that serves the web tree), for example as
  # features.gui.apps.tools.llm.pi.googleProxy.
  options.features.server.web.googleAiProxyUrl = lib.mkOption {
    type = lib.types.str;
    default = "https://${name}.${config.features.server.web.core.baseDomain}";
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        inherit name port;
        suspend = "podman-${name}.service";
      })
      {
        users.users.${name} = {
          isSystemUser = true;
          group = name;
          home = "${storage}/${name}";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.${name} = {};

        # The gateway keeps its SQLite database (settings, model configs, query log) in APP_DATA_DIR.
        systemd.tmpfiles.rules = [
          "d ${storage}/${name} 0751 ${name} web - -"
          "z ${storage}/${name} 0751 ${name} web - -"
          "d ${storage}/${name}/data 0770 ${name} ${name} - -"
          "z ${storage}/${name}/data 0770 ${name} ${name} - -"
          "d ${storage}/${name}/uv-cache 0770 ${name} ${name} - -"
          "z ${storage}/${name}/uv-cache 0770 ${name} ${name} - -"
        ];

        virtualisation.oci-containers.containers.${name} = {
          image = helpers.resolveImage "ghcr.io/highkay/googleaisearch2api:latest";
          podman.user = name;
          environment = {
            APP_HOST = "127.0.0.1";
            APP_PORT = toString port;
            API_TOKEN = "";
            APP_DATA_DIR = "/app/data";

            # No GEMINI_UPSTREAM_* credentials are configured, so the browser engine answers directly.
            SEARCH_ENGINE = "gemini";
            BROWSER_HEADLESS = "true";
            BROWSER_EXECUTABLE_PATH = "/usr/bin/chromium";

            # The image ships a prebuilt venv; never mutate it at start.
            UV_NO_SYNC = "1";
            PYTHONDONTWRITEBYTECODE = "1";

            TZ = config.time.timeZone;
          };
          volumes = ["${storage}/${name}/data:/app/data"];
          # Host networking together with the loopback bind above: the reverse proxy on this host is
          # the only thing that can reach the gateway, and no privileged port forwarding is involved.
          extraOptions = ["--network=host"];
        };

        systemd.services."podman-${name}" = {
          after = ["systemd-tmpfiles-setup.service"];
          wants = ["systemd-tmpfiles-setup.service"];
          serviceConfig = {
            # `uv run` keeps a lock next to /app/pyproject.toml and its cache under XDG_CACHE_HOME,
            # neither of which is writable for this user.
            Environment = ["UV_CACHE_DIR=${storage}/${name}/uv-cache"];
          };
        };
      }
    ]
  );
}
