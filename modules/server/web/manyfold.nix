{
  config,
  lib,
  pkgs,
  helpers ? null,
  inputs,
  ...
}: let
  cfg = config.features.server.web.manyfold;
  storage = config.features.server.web.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  autheliaEnabled = config.features.server.web.authelia.enable or false;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};

  # The solo image sets PLUGINS_PATH=/config/plugins, so plugins are scanned from
  # the `config` volume, i.e. this host directory.
  hostPluginsPath = "${storage}/manyfold/config/plugins";

  # Plugin name -> directory containing the Rails engine (plugin name must match
  # the gemspec/plugin slug).
  plugins = {
    manyfold_printables = inputs.manyfold-printables;
    manyfold_openscad = inputs.manyfold-openscad;
  };
in {
  options.features.server.web.manyfold = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        manyfold-openscad = {
          url = "https://github.com/cmeister2/manyfold_openscad/releases/download/0.3.1/manyfold_openscad.zip";
          flake = false;
        };
        manyfold-printables = {
          url = "github:nxn94/manyfold_printables";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg (
      lib.mkMerge [
        (webHelper.mkWebApp {
          name = "3d";
          aliases = [
            "manyfold"
            "models"
            "stl"
          ];
          port = 3214;
          suspend = "podman-manyfold.service";
          oidc = {
            id = "manyfold";
            name = "Manyfold";
            redirectUris = [
              "https://3d.${baseDomain}/users/auth/openid_connect/callback"
            ];
          };
        })
        {
          age.secrets.manyfold-env = {
            file = ../../../secrets/manyfold-env.age;
            owner = "manyfold";
            group = "manyfold";
            mode = "0400";
          };

          users.users.manyfold = {
            isSystemUser = true;
            group = "manyfold";
            home = "${storage}/manyfold";
            autoSubUidGidRange = true;
            linger = true;
          };
          users.groups.manyfold = {};

          systemd.tmpfiles.rules = [
            "d ${storage}/manyfold 0750 manyfold web - -"
            "z ${storage}/manyfold 0750 manyfold web - -"
            "d ${storage}/manyfold/config 0750 manyfold web - -"
            "d ${storage}/manyfold/config/plugins 0750 manyfold web - -"
            "z ${storage}/manyfold/config/plugins 0750 manyfold web - -"
            "d ${storage}/manyfold/libraries 0750 manyfold web - -"
          ];

          # The nix store is read-only and Manyfold fixes up permissions on the
          # plugins directory at startup, so mirror each plugin into the writable
          # config volume rather than bind-mounting the store path directly.
          systemd.services.manyfold-plugins = {
            description = "Sync Manyfold plugins into the config volume";
            wantedBy = ["multi-user.target"];
            before = ["podman-manyfold.service"];
            after = ["local-fs.target"];
            serviceConfig = {
              type = "oneshot";
              remainAfterExit = true;
            };
            script =
              ''
                install -d -m 0750 -o manyfold -g web ${hostPluginsPath}
              ''
              + lib.concatStringsSep "\n" (lib.mapAttrsToList (name: source: ''
                  install -d -m 0750 -o manyfold -g web ${hostPluginsPath}/${name}
                  ${pkgs.rsync}/bin/rsync -a --delete --chown=manyfold:web ${source}/ ${hostPluginsPath}/${name}/
                '')
                plugins);
          };

          virtualisation.oci-containers.containers.manyfold = {
            image = helpers.resolveImage "ghcr.io/manyfold3d/manyfold-solo:latest";
            podman.user = "manyfold";
            ports = [
              "127.0.0.1:3214:3214"
            ];
            volumes = [
              "${storage}/manyfold/config:/config"
              "${storage}/manyfold/data:/libraries"
              "${storage}/manyfold/data:/models"
            ];
            environment =
              {
                PUBLIC_HOSTNAME = "3d.${baseDomain}";
                PLUGINS_PATH = "/config/plugins";
              }
              // lib.optionalAttrs autheliaEnabled {
                OIDC_NAME = "Authelia";
                OIDC_ISSUER = "https://auth.${baseDomain}";
                OIDC_CLIENT_ID = "manyfold";
                MULTIUSER = "true";
              };
            environmentFiles = [
              config.age.secrets.manyfold-env.path
            ];
          };
        }
      ]
    ))
  ];
}
