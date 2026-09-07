{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
  podmanEnabled = config.features.compat.podman.enable or false;
in {
  options.features.core.hardware = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
    mobile = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    touchscreen = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    slow = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    bluetooth = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    pipewire = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    nvidia = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    zram = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    ldfix = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    fuse = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    appimage = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    vulnix = lib.mkOption {
      type = lib.types.bool;
      default =
        if cfg.slow
        then false
        else true;
    };
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable) {
    # Bluetooth
    hardware.bluetooth = lib.mkIf cfg.bluetooth {
      enable = true;
      powerOnBoot = true;
    };

    # Touchscreen & sensors
    hardware.sensor.iio.enable = lib.mkIf cfg.touchscreen true;

    # PipeWire sound
    services.pulseaudio.enable = lib.mkIf cfg.pipewire false;
    security.rtkit.enable = lib.mkIf cfg.pipewire true;
    services.pipewire = lib.mkIf cfg.pipewire {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # ZRAM
    zramSwap = lib.mkIf cfg.zram {
      enable = true;
      memoryPercent =
        if cfg.slow
        then 100
        else 50;
      priority = 100;
    };

    swapDevices = lib.mkIf cfg.zram [
      {
        device = "/var/swapfile";
        size = 8192;
        priority = 10;
      }
    ];

    boot.kernel.sysctl = lib.mkIf cfg.zram {
      "vm.swappiness" =
        if cfg.slow
        then 180
        else 150;
      "vm.watermark_boost_factor" = 0;
    };

    # nix-ld fix for unpatched binaries
    services.envfs.enable = lib.mkIf cfg.ldfix false;
    programs.nix-ld.enable = lib.mkIf cfg.ldfix true;
    programs.nix-ld.libraries = lib.mkIf cfg.ldfix (
      with pkgs; [
        stdenv.cc.cc.lib
        zlib
        glib.out
        openssl
        libx11
        libxcursor
        libxrandr
        libxi
        libxext
        libxfixes
        libxtst
        libGL
        libxkbcommon
        dbus
        fontconfig
        freetype
        gtk3
        pango
        cairo
        gdk-pixbuf
        atk
        nss
        nspr
        alsa-lib
        libuuid
        libdrm
        udev
        libxcb-cursor
        libxcomposite
        libxdamage
        libxrender
        libxxf86vm
        expat
        libxml2
        libpng
        vulkan-loader
      ]
    );

    environment.sessionVariables = lib.mkIf cfg.ldfix {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d";
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d";
    };

    # FUSE mounts
    programs.fuse.userAllowOther = lib.mkIf cfg.fuse true;

    environment.systemPackages =
      lib.optionals cfg.fuse [
        pkgs.cifs-utils
        pkgs.sshfs
      ]
      ++ lib.optionals (cfg.fuse && (config.features.gui.dev.android.enable or false)) [
        pkgs.adbfs-rootless
      ]
      ++ lib.optionals cfg.vulnix [pkgs.vulnix];

    fileSystems = lib.mkIf cfg.fuse {
      "/mnt/brix0" = {
        device = "//brix0/data";
        fsType = "cifs";
        options = [
          "x-systemd.automount"
          "noauto"
          "_netdev"
          "x-systemd.idle-timeout=60"
          "x-systemd.mount-timeout=2s"
          "soft"
          "uid=1000"
          "gid=100"
          "credentials=/etc/nixos/smb-secrets"
        ];
      };

      "/mnt/dane" = lib.mkIf (config.networking.hostName != "cloudburst-desktop") {
        device = "//cloudburst-desktop/dane";
        fsType = "cifs";
        options = [
          "x-systemd.automount"
          "noauto"
          "_netdev"
          "x-systemd.idle-timeout=60"
          "x-systemd.mount-timeout=2s"
          "soft"
          "uid=1000"
          "gid=100"
          "credentials=/etc/nixos/smb-secrets"
        ];
      };
    };

    # AppImage
    programs.appimage = lib.mkIf cfg.appimage {
      enable = true;
      binfmt = true;
    };

    # Nvidia
    services.xserver.videoDrivers = lib.mkIf cfg.nvidia ["nvidia"];
    hardware.nvidia = lib.mkIf cfg.nvidia {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      open = lib.mkDefault false;
      powerManagement.enable = lib.mkDefault false;
      powerManagement.finegrained = lib.mkDefault false;
      nvidiaSettings = true;
    };

    hardware.nvidia-container-toolkit.enable = lib.mkIf (cfg.nvidia && podmanEnabled) true;
    virtualisation.containers.cdi.dynamic.nvidia.enable = lib.mkIf (cfg.nvidia && podmanEnabled) true;
  };
}
