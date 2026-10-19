{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.proxmox;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  localPort = 8006;
in {
  options.features.server.web.proxmox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "proxmox";
        aliases = [
          "pve"
        ];
        upstream = "nixos-lxc:8006";
        port = localPort;
        cors = true;
        extraProxyConfig = ''
          transport http {
            tls_insecure_skip_verify
          }
        '';
      })
    ]
  );
}
