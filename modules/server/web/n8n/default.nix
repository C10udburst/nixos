{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.n8n;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  baseDomain = webCfg.core.baseDomain or "example.com";
  domain = "flows.${baseDomain}";
  port = 5678;
  user = "n8n";
  webHelper = import ../_webService.nix {inherit config lib pkgs;};

  # The node that drives pi-web, with its own packaging in _pi-web-node/default.nix.
  piWebNode = import ./_pi-web-node {inherit pkgs lib;};
in {
  options.features.server.web.n8n = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = webCfg.enable && true;
    };

    # Community node packages beyond the bundled one. Anything nixpkgs ships works
    # as-is (pkgs.n8n-nodes-carbonejs, pkgs.n8n-nodes-evolution-api): the layout they
    # all share is $out/lib/node_modules/<pname>, which is what the linkFarm links.
    nodes = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
    };

    # The n8n-nodes-pi-web node: sessions of the pi-web instance fronted by
    # features.server.web.pi.
    piWeb = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.n8n.enable && false;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "n8n";
        aliases = [
          "flow"
          "flows"
        ];
        inherit port;
        # The editor streams workflow and execution updates over a websocket.
        extraProxyConfig = ''
          flush_interval -1
        '';
      })
      {
        # No OIDC here: n8n ships SSO (SAML/OIDC/LDAP) as a licensed module, so the instance
        # answers with its own owner account and MFA. `protect` of mkWebApp stays free for
        # Authelia forward-auth, which would also lock the webhook endpoints callers post to.
        age.secrets.n8n-encryption-key = {
          file = ../../../../secrets/n8n-encryption-key.age;
        };

        users.users.${user} = {
          isSystemUser = true;
          group = user;
          home = "${storage}/n8n";
        };
        users.groups.${user} = {};

        # N8N_USER_FOLDER is a read-only option pinned to /var/lib/n8n, so the data reaches
        # the storage mount through the symlink the other apps use. Variables ending in _FILE
        # are handed to the unit as systemd credentials by the upstream module, read from the
        # read-only $CREDENTIALS_DIRECTORY the service gets.
        systemd.tmpfiles.rules = [
          "d ${storage}/n8n 2750 ${user} web - -"
          "z ${storage}/n8n 2750 ${user} web - -"
          "L+ /var/lib/n8n - - - - ${storage}/n8n"
        ];

        services.postgresql = {
          enable = true;
          ensureDatabases = [user];
          ensureUsers = [
            {
              name = user;
              ensureDBOwnership = true;
            }
          ];
          authentication = lib.mkBefore ''
            host ${user} ${user} 127.0.0.1/32 trust
            host ${user} ${user} ::1/128 trust
          '';
        };

        services.n8n = {
          enable = true;
          customNodes = lib.optionals cfg.piWeb [piWebNode] ++ cfg.nodes;
          environment = {
            N8N_PORT = port;
            # Default is ::, which would answer the LAN beside Caddy.
            N8N_LISTEN_ADDRESS = "127.0.0.1";
            N8N_HOST = domain;
            N8N_PROTOCOL = "https";
            N8N_PROXY_HOPS = 1;
            N8N_EDITOR_BASE_URL = "https://${domain}/";
            # WEBHOOK_URL is the deprecated alias of this one since n8n 2.35.
            N8N_WEBHOOK_URL = "https://${domain}/";
            N8N_ENCRYPTION_KEY_FILE = config.age.secrets.n8n-encryption-key.path;
            # Binary payloads belong on the data folder, not in the database rows.
            N8N_DEFAULT_BINARY_DATA_MODE = "filesystem";
            DB_TYPE = "postgresdb";
            DB_POSTGRESDB_HOST = "127.0.0.1";
            DB_POSTGRESDB_PORT = 5432;
            DB_POSTGRESDB_DATABASE = user;
            DB_POSTGRESDB_USER = user;
            # Keeps the execution table from growing without bound (hours).
            EXECUTIONS_DATA_PRUNE = true;
            EXECUTIONS_DATA_MAX_AGE = 168;
          };
        };

        systemd.services.n8n = {
          after = ["postgresql.service"];
          requires = ["postgresql.service"];
          serviceConfig = {
            # DynamicUser cannot own the data directory on the storage mount, and the
            # StateDirectory it would make stands in front of the symlink above.
            DynamicUser = lib.mkForce false;
            User = user;
            Group = user;
            SupplementaryGroups = ["web"];
            StateDirectory = lib.mkForce [];
            ReadWritePaths = [
              "${storage}/n8n"
            ];
          };
        };
      }
    ]
  );
}
