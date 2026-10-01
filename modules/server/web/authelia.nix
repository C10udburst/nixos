{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.authelia;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  port = 9091;
  instanceName = "main";
  domain = "auth.${baseDomain}";
  autheliaUser = "authelia-${instanceName}";
in {
  options.features.server.web.authelia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    _oidcClients = lib.mkOption {
      internal = true;
      type = lib.types.listOf lib.types.attrs;
      default = [];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "auth";
        aliases = [
          "authelia"
          "login"
        ];
        port = port;
      })
      {
        users.users.${autheliaUser}.extraGroups = ["web"];

        systemd.tmpfiles.rules = [
          "d ${storage}/authelia 0750 ${autheliaUser} web - -"
          "z ${storage}/authelia 0750 ${autheliaUser} web - -"
        ];

        systemd.services."authelia-${instanceName}" = {
          serviceConfig = {
            ReadWritePaths = [
              storage
              "-${storage}/authelia"
            ];
          };
          preStart = lib.mkBefore ''
            mkdir -p ${storage}/authelia
          '';
        };

        age.secrets.authelia-users = {
          file = ../../../secrets/authelia-users.age;
          owner = autheliaUser;
          group = autheliaUser;
          mode = "0400";
        };
        age.secrets.authelia-jwt = {
          file = ../../../secrets/authelia-jwt.age;
          owner = autheliaUser;
          group = autheliaUser;
          mode = "0400";
        };
        age.secrets.authelia-storage = {
          file = ../../../secrets/authelia-storage.age;
          owner = autheliaUser;
          group = autheliaUser;
          mode = "0400";
        };
        age.secrets.authelia-oidc-hmac = {
          file = ../../../secrets/authelia-oidc-hmac.age;
          owner = autheliaUser;
          group = autheliaUser;
          mode = "0400";
        };
        age.secrets.authelia-oidc-key = {
          file = ../../../secrets/authelia-oidc-key.age;
          owner = autheliaUser;
          group = autheliaUser;
          mode = "0400";
        };
        age.secrets.authelia-oidc-clients = {
          file = ../../../secrets/authelia-oidc-clients.age;
          owner = autheliaUser;
          group = autheliaUser;
          mode = "0400";
        };

        services.authelia.instances.${instanceName} = {
          enable = true;
          environmentVariables = {
            X_AUTHELIA_CONFIG_FILTERS = "template";
          };
          secrets = {
            jwtSecretFile = config.age.secrets.authelia-jwt.path;
            storageEncryptionKeyFile = config.age.secrets.authelia-storage.path;
            oidcHmacSecretFile = config.age.secrets.authelia-oidc-hmac.path;
            oidcIssuerPrivateKeyFile = config.age.secrets.authelia-oidc-key.path;
          };
          settings = {
            theme = "auto";
            default_2fa_method = "webauthn";
            server = {
              address = "tcp://127.0.0.1:${toString port}";
              endpoints.authz.forward-auth.implementation = "ForwardAuth";
              buffers = {
                read = 4096;
                write = 4096;
              };
            };
            log.level = "info";
            webauthn = {
              enable_passkey_login = true;
              display_name = baseDomain;
            };
            totp = {
              issuer = baseDomain;
            };
            authentication_backend = {
              file = {
                path = config.age.secrets.authelia-users.path;
                watch = false;
                password.algorithm = "argon2";
              };
            };
            access_control = {
              default_policy = "one_factor";
              rules = [
                {
                  domain = [domain];
                  policy = "bypass";
                }
              ];
            };
            session = {
              name = "authelia_session";
              cookies = [
                {
                  domain = baseDomain;
                  authelia_url = "https://${domain}";
                  default_redirection_url = "https://home.${baseDomain}";
                }
              ];
            };
            storage = {
              local = {
                path = "${storage}/authelia/db.sqlite3";
              };
            };
            notifier = {
              filesystem = {
                filename = "/var/lib/authelia-${instanceName}/notification.txt";
              };
            };
            identity_providers = {
              oidc = {
                claims_policies = {
                  default = {
                    id_token = [
                      "email"
                      "email_verified"
                      "alt_emails"
                      "groups"
                      "name"
                      "preferred_username"
                      "profile"
                      "picture"
                    ];
                  };
                };
                cors = {
                  endpoints = [
                    "authorization"
                    "token"
                    "revocation"
                    "introspection"
                    "userinfo"
                  ];
                  allowed_origins_from_client_redirect_uris = true;
                };
                clients = cfg._oidcClients;
              };
            };
          };
        };
      }
    ]
  );
}
