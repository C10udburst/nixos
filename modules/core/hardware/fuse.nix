{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.fuse = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && true;
  };

  config = lib.mkIf cfg.fuse {
    programs.fuse.userAllowOther = true;

    environment.systemPackages =
      [
        pkgs.cifs-utils
        pkgs.sshfs
      ]
      ++ lib.optionals (config.features.gui.dev.android.enable or false) [
        pkgs.adbfs-rootless
      ];

    age.secrets.smb-secrets = {
      file = ../../../secrets/smb-secrets.age;
    };

    fileSystems = {
      "/mnt/brix0" = lib.mkIf (config.networking.hostName != "brix0") {
        device = "//brix0/dane";
        fsType = "cifs";
        options = [
          "x-systemd.automount"
          "noauto"
          "_netdev"
          "x-systemd.mount-timeout=2s"
          "uid=1000"
          "gid=100"
          "credentials=${config.age.secrets.smb-secrets.path}"
        ];
      };

      "/mnt/dane" = lib.mkIf (config.networking.hostName != "cloudburst-desktop") {
        device = "//cloudburst-desktop/dane";
        fsType = "cifs";
        options = [
          "x-systemd.automount"
          "noauto"
          "_netdev"
          "x-systemd.mount-timeout=2s"
          "uid=1000"
          "gid=100"
          "credentials=${config.age.secrets.smb-secrets.path}"
        ];
      };
    };
  };
}
