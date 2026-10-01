{
  config,
  lib,
  ...
}: let
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  sablierEnabled = config.features.server.web.sablier.enable or false;
  sablierHostPort = "127.0.0.1:10000";

  autheliaCfg = config.features.server.web.authelia or {};
  autheliaEnabled = autheliaCfg.enable or false;
  autheliaPort = autheliaCfg.port or 9091;
  autheliaDomain = autheliaCfg.domain or "auth.${baseDomain}";

  homeAncestors = "https://home.${baseDomain}";
  allowedAncestors = "'self' ${homeAncestors}";

  mkOidcClient = {
    id,
    name ? id,
    redirectUris,
    scopes ? ["openid" "profile" "email"],
    policy ? "one_factor",
    claimsPolicy ? "default",
    pkce ? false,
    public ? false,
    hashedSecret ? null,
    ...
  }: let
    clientsSecretPath = config.age.secrets.authelia-oidc-clients.path or "/run/agenix/authelia-oidc-clients";
  in
    {
      client_id = id;
      client_name = name;
      inherit public scopes;
      authorization_policy = policy;
      claims_policy = claimsPolicy;
      redirect_uris = redirectUris;
      require_pkce =
        if public
        then true
        else pkce;
      pkce_challenge_method =
        if (public || pkce)
        then "S256"
        else null;
      response_types = ["code"];
      grant_types = ["authorization_code"];
      access_token_signed_response_alg = "none";
      userinfo_signed_response_alg = "none";
      token_endpoint_auth_method =
        if public
        then "none"
        else "client_secret_basic";
    }
    // lib.optionalAttrs (!public) {
      client_secret =
        if hashedSecret != null
        then hashedSecret
        else "{{ (secret \"${clientsSecretPath}\" | fromYaml).secrets.${id} }}";
    };

  mkWebApp = {
    name,
    aliases ? [],
    port ? null,
    socket ? null,
    suspend ? null,
    cors ? false,
    protect ? [],
    oidc ? null,
    extraConfig ? "",
  }: let
    domain = "${name}.${baseDomain}";
    upstream =
      if socket != null
      then "unix/${socket}"
      else if port != null
      then "127.0.0.1:${toString port}"
      else throw "mkWebApp requires either port or socket for ${name}";

    suspendList =
      if suspend == null
      then []
      else if lib.isList suspend
      then suspend
      else [suspend];

    protectList =
      if protect == true
      then ["*"]
      else if protect == false || protect == null
      then []
      else if lib.isList protect
      then protect
      else [protect];

    safeName = lib.replaceStrings ["-" "."] ["_" "_"] name;

    protectAll = builtins.elem "*" protectList || builtins.elem "/*" protectList;

    isRegex = builtins.any (p: lib.hasPrefix "^" p) protectList;

    matcherDef =
      if protectAll
      then ""
      else if isRegex
      then "@auth_protected path_regexp ${lib.concatStringsSep " " protectList}"
      else "@auth_protected path ${lib.concatStringsSep " " protectList}";

    matcherArg =
      if protectAll
      then ""
      else "@auth_protected ";

    autheliaForwardAuth = lib.optionalString (protectList != [] && autheliaEnabled) ''
      ${matcherDef}
      forward_auth ${matcherArg}127.0.0.1:${toString autheliaPort} {
        uri /api/authz/forward-auth?authelia_url=https://${autheliaDomain}/
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
      }
    '';

    sablierPoke = lib.optionalString (suspendList != [] && sablierEnabled) ''
      forward_auth ${sablierHostPort} {
        uri /api/strategies/poke?group=${name}
        header_up -Content-Type
        header_up -Content-Length
        @failures status 4xx 5xx
        handle_response @failures {
        }
      }
    '';

    sablierHandler = lib.optionalString (suspendList != [] && sablierEnabled) ''
      @down expression `{err.status_code} in [502, 503, 504]`
      handle @down {
        rewrite * /api/strategies/dynamic?group=${name}
        method GET
        reverse_proxy ${sablierHostPort} {
          header_up -Content-Type
          header_up -Content-Length
        }
      }
    '';

    oidcClient =
      if oidc != null && oidc != false
      then mkOidcClient ({id = name;} // oidc)
      else null;
  in {
    features.server.web.core._apps = [
      {
        inherit name aliases port;
        suspend = suspendList;
        protect = protectList;
      }
    ];
    features.server.web.authelia._oidcClients = lib.optional (oidcClient != null) oidcClient;
    services.caddy.virtualHosts."${domain}" = {
      useACMEHost = lib.mkIf (config.features.server.web.ssl.enable or false) baseDomain;
      extraConfig = ''
        log error_${safeName} {
          output file /var/log/caddy/error-${name}.log {
            roll_size 10MB
            roll_keep 10
            roll_keep_for 720h
          }
          format json
          no_hostname
        }

        header -X-Frame-Options
        header ?Content-Security-Policy "frame-ancestors ${allowedAncestors}"

        ${sablierPoke}

        handle_errors {
          log_name error_${safeName}
          ${sablierHandler}
        }

        ${lib.optionalString cors ''
          @cors_preflight method OPTIONS
          handle @cors_preflight {
            header Access-Control-Allow-Origin *
            header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD"
            header Access-Control-Allow-Headers *
            header Access-Control-Max-Age 86400
            respond "" 204
          }
        ''}

        handle {
          ${autheliaForwardAuth}
          ${extraConfig}
          reverse_proxy ${upstream} {
            header_down -X-Frame-Options
            header_down Content-Security-Policy "frame-ancestors 'none'" "frame-ancestors 'self'"
            header_down Content-Security-Policy "frame-ancestors ([^;]+)" "frame-ancestors $1 ${homeAncestors}"
            ${lib.optionalString cors ''
          header_down -Access-Control-Allow-Origin
          header_down Access-Control-Allow-Origin *
          header_down -Access-Control-Allow-Methods
          header_down Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD"
          header_down -Access-Control-Allow-Headers
          header_down Access-Control-Allow-Headers *
          header_down -Access-Control-Expose-Headers
          header_down Access-Control-Expose-Headers *
        ''}
            @err status 5xx
            handle_response @err {
              log_name error_${safeName}
              copy_response
            }
          }
        }
      '';
    };
  };
in {
  inherit mkWebApp mkOidcClient allowedAncestors homeAncestors;
}
