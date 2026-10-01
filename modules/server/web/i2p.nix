{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.i2p;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  sablierEnabled = config.features.server.web.sablier.enable or false;
  sablierHostPort = "127.0.0.1:10000";
  webHelper = import ./_webService.nix {inherit config lib pkgs;};

  sablierConfig = lib.optionalString sablierEnabled ''
    forward_auth ${sablierHostPort} {
      uri /api/strategies/poke?group=i2p
      header_up -Content-Type
      header_up -Content-Length
      @failures status 4xx 5xx
      handle_response @failures {
      }
    }
    handle_errors {
      @down expression `{err.status_code} in [502, 503, 504]`
      handle @down {
        rewrite * /api/strategies/dynamic?group=i2p
        method GET
        reverse_proxy ${sablierHostPort} {
          header_up -Content-Type
          header_up -Content-Length
        }
      }
    }
  '';
in {
  options.features.server.web.i2p = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "i2p";
        aliases = ["i2prouter"];
        port = 7657;
        suspend = "i2pd.service";
      })
      {
        services.i2pd = {
          enable = true;
          port = 4567;
          upnp.enable = true;
          addressbook = {
            defaulturl = "http://shx5vqsw7usdaunyzr2qmes2fq37oumybpudrd4jjj4e4vk4uusa.b32.i2p/hosts.txt";
            subscriptions = [
              "http://shx5vqsw7usdaunyzr2qmes2fq37oumybpudrd4jjj4e4vk4uusa.b32.i2p/hosts.txt"
              "http://reg.i2p/hosts.txt"
              "http://stats.i2p/cgi-bin/newhosts.txt"
              "http://identiguy.i2p/hosts.txt"
            ];
          };
          proto.http = {
            enable = true;
            address = "127.0.0.1";
            port = 7657;
            strictHeaders = false;
            hostname = "i2prouter.local";
          };
          proto.httpProxy = {
            enable = true;
          };
        };

        networking.firewall.allowedTCPPorts = [4567];
        networking.firewall.allowedUDPPorts = [4567];

        systemd.services.i2pd.preStart = ''
          mkdir -p /var/lib/i2pd/addressbook
          touch /var/lib/i2pd/addressbook/addresses.csv
          for entry in \
            "reg.i2p,shx5vqsw7usdaunyzr2qmes2fq37oumybpudrd4jjj4e4vk4uusa" \
            "stats.i2p,7tbay5p4kzeekxvyvbf6v7eauazemsnnl2aoyqhg5jzpr5eke7tq" \
            "identiguy.i2p,3mzmrus2oron5fxptw7hw2puho3bnqmw2hqy7nw64dsrrjwdilva" \
            "notbob.i2p,nytzrhrjjfsutowojvxi7hphesskpqqr65wpistz6wa7cpajhp7a"; do
            domain="''${entry%%,*}"
            if ! grep -q "^$domain," /var/lib/i2pd/addressbook/addresses.csv 2>/dev/null; then
              echo "$entry" >> /var/lib/i2pd/addressbook/addresses.csv
            fi
          done
          chown -R i2pd:i2pd /var/lib/i2pd/addressbook
        '';

        services.caddy.virtualHosts = {
          "http://*.i2p, http://*.*.i2p, http://*.*.*.i2p, http://*.*.*.*.i2p, http://i2p" = {
            extraConfig = ''
              ${sablierConfig}

              header Content-Security-Policy "default-src 'self' *.i2p; script-src 'none'; object-src 'none'; style-src 'self' *.i2p 'unsafe-inline'; img-src 'self' *.i2p data:; font-src 'self' *.i2p data:; media-src 'self' *.i2p; frame-src 'self' *.i2p; form-action 'self' *.i2p; base-uri 'self' *.i2p;"

              reverse_proxy 127.0.0.1:4444 {
                header_up Host {host}
                header_up -X-Forwarded-For
                header_up -X-Forwarded-Proto
                header_up -X-Forwarded-Host
                header_down -Content-Security-Policy
              }
            '';
          };

          "http://i2prouter, http://i2prouter.local, http://i2prouter.lan, http://i2prouter.home" = {
            extraConfig = ''
              ${sablierConfig}

              reverse_proxy 127.0.0.1:7657
            '';
          };
        };
      }
    ]
  );
}
