{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.fuse;
in {
  options.systemSettings.fuse = {
    enable = lib.mkEnableOption "Enable mounts (SMB, ADB, SSHFS)";
  };

  config = lib.mkIf cfg.enable {
    programs.fuse.userAllowOther = true;

    environment.systemPackages = with pkgs; [
      cifs-utils
      adbfs-rootless
      sshfs
    ];

    # Mountpoint for SMB brix0.taile505b.ts.net/data
    fileSystems."/mnt/brix0" = {
      device = "//brix0.taile505b.ts.net/data";
      fsType = "cifs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "uid=1000"
        "gid=100"
        "credentials=/etc/nixos/smb-secrets"
      ];
    };

    # Mountpoint for SMB cloudburst-desktop/dane
    fileSystems."/mnt/dane" = lib.mkIf (config.networking.hostName != "cloudburst-desktop") {
      device = "//cloudburst-desktop.taile505b.ts.net/dane";
      fsType = "cifs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "uid=1000"
        "gid=100"
        "credentials=/etc/nixos/smb-secrets"
      ];
    };
  };
}
