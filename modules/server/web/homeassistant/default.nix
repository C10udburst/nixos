{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.homeassistant;
  storage = config.features.server.web.storage;
  webHelper = import ../_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.homeassistant = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0:/dev/ttyUSB0"
      ];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "hass";
        aliases = [
          "home-assistant"
          "ha"
        ];
        port = 8123;
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/homeassistant 0755 root web - -"
          "z ${storage}/homeassistant 0755 root web - -"
          "d ${storage}/homeassistant/config 0775 root web - -"
          "z ${storage}/homeassistant/config 0775 root web - -"
        ];

        virtualisation.oci-containers.containers.homeassistant = {
          image = helpers.resolveImage "ghcr.io/home-assistant/home-assistant:stable";
          inherit (cfg) devices;
          volumes = [
            "${storage}/homeassistant/config:/config"
            "/etc/localtime:/etc/localtime:ro"
            "/run/dbus:/run/dbus:ro"
          ];
          extraOptions = [
            "--network=host"
            "--privileged"
          ];
        };
      }
    ]
  );
}
