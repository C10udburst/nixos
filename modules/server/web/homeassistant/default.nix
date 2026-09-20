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
        users.users.homeassistant = {
          isSystemUser = true;
          group = "homeassistant";
          home = "${storage}/homeassistant";
          autoSubUidGidRange = true;
          linger = true;
          extraGroups = ["dialout"];
        };
        users.groups.homeassistant = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/homeassistant 0755 homeassistant web - -"
          "z ${storage}/homeassistant 0755 homeassistant web - -"
          "d ${storage}/homeassistant/config 0750 homeassistant web - -"
        ];

        virtualisation.oci-containers.containers.homeassistant = {
          image = helpers.resolveImage "ghcr.io/home-assistant/home-assistant:stable";
          podman.user = "homeassistant";
          inherit (cfg) devices;
          volumes = [
            "${storage}/homeassistant/config:/config"
            "/etc/localtime:/etc/localtime:ro"
            "/run/dbus:/run/dbus:ro"
          ];
          extraOptions = [
            "--network=host"
            "--group-add=keep-groups"
          ];
        };
      }
    ]
  );
}
