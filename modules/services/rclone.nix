{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.services.rclone;
in {
  imports = lib.optionals (inputs ? rclone-flake && inputs.rclone-flake ? nixosModules) [
    inputs.rclone-flake.nixosModules.default
  ];

  options.features.services.rclone = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.services.enable && false;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        rclone-flake = {
          url = "github:C10udburst/rclone-flake";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.rclone
      ];

      age.secrets.rclone-conf = {
        file = ../../secrets/rclone-conf.age;
      };

      services.rclone = {
        enable = true;
        globalConfigFile = config.age.secrets.rclone-conf.path;

        mounts = lib.mkIf (config.networking.hostName == "brix0") {
          "pw-isi" = {
            mountPoint = "/opt/dane/onyx/PW/ISI";
            allowOther = true;
            allowNonEmpty = true;
            vfsCacheMode = "writes";
            uid = 1000;
            gid = 100;
            umask = "002";
            union = {
              enable = true;
              remote = "gdrive:Studia/mini";
            };
          };

          "pw-iad" = {
            mountPoint = "/opt/dane/onyx/PW/IAD";
            allowOther = true;
            allowNonEmpty = true;
            vfsCacheMode = "writes";
            uid = 1000;
            gid = 100;
            umask = "002";
            union = {
              enable = true;
              remote = "gdrive:Studia/IAD";
            };
          };

          "pw-smad" = {
            mountPoint = "/opt/dane/onyx/PW/SMAD";
            allowOther = true;
            allowNonEmpty = true;
            vfsCacheMode = "writes";
            uid = 1000;
            gid = 100;
            umask = "002";
            union = {
              enable = true;
              remote = "gdrive:Studia/Smad";
            };
          };
        };
      };
    })
  ];
}
