{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware.ssd;
  isSlow = config.features.core.hardware.slow or false;
  hasBtrfs = lib.any (fs: fs.fsType == "btrfs") (builtins.attrValues config.fileSystems);
in {
  options.features.core.hardware.ssd = lib.mkOption {
    type = lib.types.coercedTo lib.types.bool (b: {enable = b;}) (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.features.core.hardware.enable && true;
          };
          fstrim = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          btrfsAutoScrub = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          smartd = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          tools = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
      }
    );
    default = {};
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.fstrim.enable = cfg.fstrim;

      services.btrfs.autoScrub = {
        enable = cfg.btrfsAutoScrub && hasBtrfs;
        interval = "monthly";
      };

      services.smartd = lib.mkIf cfg.smartd {
        enable = true;
        autodetect = true;
      };

      environment.systemPackages = lib.optionals cfg.tools [
        pkgs.smartmontools
        pkgs.nvme-cli
      ];

      boot.kernel.sysctl = {
        "vm.vfs_cache_pressure" = lib.mkDefault (
          if isSlow
          then 100
          else 50
        );
      };
    })
    (lib.mkIf (!cfg.enable) {
      services.fstrim.enable = lib.mkDefault false;
      services.btrfs.autoScrub.enable = lib.mkDefault false;
      services.smartd.enable = lib.mkDefault false;
    })
  ];
}
