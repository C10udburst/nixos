{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.copyparty;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};

  volumesConfig =
    if (builtins.length cfg.paths == 1)
    then ''
      [/]
        ${builtins.head cfg.paths}
        accs:
          A: cloudburst
          g: *
    ''
    else
      lib.concatMapStrings (p: ''
        [/${baseNameOf p}]
          ${p}
          accs:
            A: cloudburst
            g: *
      '')
      cfg.paths;

  copypartyConf = pkgs.writeText "copyparty.conf" ''
    [global]
      p: 3923
      i: 127.0.0.1
      xff-src: lan
      xf-proto: X-Forwarded-Proto
      xf-host: X-Forwarded-Host
      rproxy: -1

      z, qr

    ${volumesConfig}
  '';
in {
  options.features.server.web.copyparty = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["${storage}/dane"];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "files";
        aliases = [
          "file"
          "drive"
          "copyparty"
        ];
        port = 3923;
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        age.secrets.copyparty-accounts = {
          file = ../../../secrets/copyparty-accounts.age;
          owner = "cloudburst";
          group = "web";
          mode = "0400";
        };

        systemd.tmpfiles.rules = lib.concatMap (p: [
          "d ${p} 2750 cloudburst web - -"
          "z ${p} 2750 cloudburst web - -"
        ]) (builtins.filter (p: lib.hasPrefix storage p) cfg.paths);

        systemd.services.copyparty = {
          description = "Copyparty file server";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          serviceConfig = {
            User = "cloudburst";
            Group = "web";
            ExecStart = ''
              ${pkgs.copyparty}/bin/copyparty \
                -c ${copypartyConf} \
                -c ${config.age.secrets.copyparty-accounts.path}
            '';
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      }
    ]
  );
}
