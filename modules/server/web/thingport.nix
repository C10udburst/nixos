{
  config,
  lib,
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
  webHelper = import ./_webService.nix {inherit config lib;};

  # The frontend proxies /api/* to http://backend:8000 by container name, which no
  # rootless network of its own answers, so the backend takes the host network (also how it
  # reaches PostgreSQL on 127.0.0.1) and the frontend gets `backend` as a host entry pointing
  # at the gateway. Both ports are part of the frontend image either way.
  apiPort = 8000;
  webPort = 3218;
  hostGateway = "169.254.1.2";
  # Slug of the provider in the database, naming the callback path.
  oidcSlug = "authelia";

  backend = "thingport-backend";
  frontend = "thingport-frontend";
  user = "thingport";
in {
  options.features.server.web.thingport = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "3d";
        aliases = [
          "thingport"
          "prints"
          "thing"
          "stl"
        ];
        port = webPort;
        suspend = [
          "podman-${backend}.service"
          "podman-${frontend}.service"
        ];
        oidc = {
          id = "thingport";
          name = "Thingport";
          pkce = true;
          redirectUris = [
            "https://${domain}/api/auth/oidc/${oidcSlug}/callback"
          ];
        };
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

        # Not group `web` like the other apps' data: the backend chowns the folders it writes
        # to uid/gid 1000, a subordinate id inside the container, and chown(2) fails with EPERM
        # when the folder's current group has no mapping there. Reach is up to the 0750 home
        # directory above; the wider bits let the backup job read storage and people drop files
        # into consume. Migrate is only ever read, so it keeps web.
        systemd.tmpfiles.rules = [
          "d ${storage}/thingport 0750 ${user} web - -"
          "z ${storage}/thingport 0750 ${user} web - -"
          "d ${storage}/thingport/storage 0755 ${user} ${user} - -"
          "d ${storage}/thingport/consume 0777 ${user} ${user} - -"
          "d ${storage}/thingport/migrate 2775 ${user} web - -"
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

        systemd.services."podman-${backend}" = {
          after = ["postgresql.service"];
          requires = ["postgresql.service"];

          # A rebuild hands the folders back to the account while a running app writes as the
          # id it took them with, so every start gives them back. `podman unshare` works out
          # which host id 1000 is, keeping /etc/subuid out of the configuration.
          path = [
            config.virtualisation.podman.package
          ];
          preStart = ''
            podman unshare chown 1000 \
              ${storage}/thingport/storage \
              ${storage}/thingport/consume \
              || echo "thingport: could not hand the folders to the container uid" >&2
          '';
        };

        virtualisation.oci-containers.containers.${backend} = {
          image = helpers.resolveImage "ghcr.io/tautvydasderzinskas/thingport-backend:latest";
          podman.user = user;
          extraOptions = [
            "--network=host"
            # The generated container hosts file points every app domain at the podman
            # gateway, which is right for bridge containers and unreachable for one sharing
            # the host namespace. Loopback is where Caddy answers, and single sign-on needs
            # it to read Authelia's discovery document.
            "--add-host=auth.${baseDomain}:127.0.0.1"
            "--add-host=3d.${baseDomain}:127.0.0.1"
            "--add-host=llm.${baseDomain}:127.0.0.1"
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
              PUBLIC_URL = "https://${domain}";
              CORS_ORIGINS = "https://${domain}";
              TZ = config.time.timeZone;
            }
            // lib.optionalAttrs flaresolverrEnabled {
              FLARESOLVERR_URL = "http://127.0.0.1:${toString flaresolverrPort}/v1";
              FLARESOLVERR_REQUIRE_HTTPS = "true";
            };
        };

        virtualisation.oci-containers.containers.${frontend} = {
          image = helpers.resolveImage "ghcr.io/tautvydasderzinskas/thingport-frontend:latest";
          podman.user = user;
          dependsOn = [backend];
          ports = [
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
