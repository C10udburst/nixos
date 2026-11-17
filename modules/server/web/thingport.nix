{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.thingport;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  baseDomain = webCfg.core.baseDomain or "example.com";
  domain = "thingport.${baseDomain}";
  flaresolverrCfg = config.features.services.flaresolverr or {};
  flaresolverrEnabled = flaresolverrCfg.enable or false;
  flaresolverrPort = flaresolverrCfg.port or 8191;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};

  # The frontend image runs nginx and proxies /api/* to http://backend:8000 by container
  # name, so the API port is fixed by the image and `backend` has to resolve somewhere.
  # There is no compose network here: the backend shares the host network namespace (which
  # is also how it reaches the local PostgreSQL on 127.0.0.1), and the frontend -- which
  # keeps its own rootless network, since nginx binds port 80 inside the container -- is
  # given `backend` as a host entry pointing at the host gateway.
  apiPort = 8000;
  webPort = 3218;
  hostGateway = "169.254.1.2";

  backend = "thingport-backend";
  frontend = "thingport-frontend";
  user = "thingport";

  # Slug of the sign-in provider inside Thingport (Administration -> Auth -> Sign-in
  # Methods). It names the callback path and cannot change once the provider is added.
  oidcSlug = "authelia";
in {
  options.features.server.web.thingport = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "thingport";
        aliases = [
          "tp"
          "prints"
          "thing"
        ];
        port = webPort;
        suspend = [
          "podman-${backend}.service"
          "podman-${frontend}.service"
        ];
        oidc = {
          id = "thingport";
          name = "Thingport";
          # Thingport always signs in with the authorization code flow and PKCE (S256).
          pkce = true;
          redirectUris = [
            "https://${domain}/api/auth/oidc/${oidcSlug}/callback"
          ];
        };
        # Uploads up to 512 MB and answers that take minutes (a slow local AI writing a
        # description, a connected instance streaming a partner's files back) are passed
        # through as they come rather than buffered. Caddy puts no cap of its own on the
        # body size; the frontend's nginx keeps its 512 MB limit.
        extraProxyConfig = ''
          flush_interval -1
        '';
      })
      {
        users.users.${user} = {
          isSystemUser = true;
          group = user;
          home = "${storage}/thingport";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.${user} = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/thingport 0750 ${user} web - -"
          "z ${storage}/thingport 0750 ${user} web - -"
          # FILE_STORAGE, the consume folder watched by Administration -> Storage, and the
          # folder Administration -> Migrate reads another instance's dump from.
          "d ${storage}/thingport/storage 0750 ${user} web - -"
          "d ${storage}/thingport/consume 0750 ${user} web - -"
          "d ${storage}/thingport/migrate 0750 ${user} web - -"
        ];

        services.postgresql = {
          enable = true;
          ensureDatabases = ["thingport"];
          ensureUsers = [
            {
              name = user;
              ensureDBOwnership = true;
            }
          ];
          authentication = lib.mkBefore ''
            host thingport thingport 127.0.0.1/32 trust
            host thingport thingport ::1/128 trust
          '';
        };

        # Prisma migrations run in the backend's entrypoint, so the database comes first.
        systemd.services."podman-${backend}" = {
          after = ["postgresql.service"];
          requires = ["postgresql.service"];
        };

        virtualisation.oci-containers.containers.${backend} = {
          image = helpers.resolveImage "ghcr.io/tautvydasderzinskas/thingport-backend:latest";
          podman.user = user;
          extraOptions = [
            "--network=host"
          ];
          volumes = [
            "${storage}/thingport/storage:/app/storage"
            "${storage}/thingport/consume:/app/consume"
            "${storage}/thingport/migrate:/app/migrate:ro"
          ];
          environment =
            {
              API_PORT = toString apiPort;
              FILE_STORAGE = "/app/storage";
              DATABASE_URL = "postgresql://${user}@127.0.0.1:5432/thingport?schema=public";
              # Seeds Administration -> Auth -> Public URL, which single sign-on needs.
              PUBLIC_URL = "https://${domain}";
              CORS_ORIGINS = "https://${domain}";
              TZ = config.time.timeZone;
            }
            // lib.optionalAttrs flaresolverrEnabled {
              # Seeded into Administration -> Connections -> FlareSolverr on first start.
              FLARESOLVERR_URL = "http://127.0.0.1:${toString flaresolverrPort}/v1";
              # Plain HTTP is then allowed for the loopback solver only.
              FLARESOLVERR_REQUIRE_HTTPS = "true";
            };
        };

        virtualisation.oci-containers.containers.${frontend} = {
          image = helpers.resolveImage "ghcr.io/tautvydasderzinskas/thingport-frontend:latest";
          podman.user = user;
          dependsOn = [backend];
          ports = [
            # The image always listens on 80 internally; only the host port is ours to pick.
            "127.0.0.1:${toString webPort}:80"
          ];
          extraOptions = [
            "--add-host=backend:${hostGateway}"
          ];
        };
      }
    ]
  );
}
