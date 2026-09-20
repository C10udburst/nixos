{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.bluetooth = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && true;
  };

  config = lib.mkIf cfg.bluetooth {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    users.groups.bluetooth = {};

    services.dbus.packages = [
      (pkgs.writeTextFile {
        name = "bluetooth-group-dbus-conf";
        destination = "/share/dbus-1/system.d/bluetooth-group.conf";
        text = ''
          <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
           "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
          <busconfig>
            <policy group="bluetooth">
              <allow send_destination="org.bluez"/>
              <allow send_interface="org.bluez.GattCharacteristic1"/>
              <allow send_interface="org.bluez.GattDescriptor1"/>
              <allow send_interface="org.bluez.GattService1"/>
              <allow send_interface="org.freedesktop.DBus.ObjectManager"/>
              <allow send_interface="org.freedesktop.DBus.Properties"/>
            </policy>
          </busconfig>
        '';
      })
    ];
  };
}
