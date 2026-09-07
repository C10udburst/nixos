{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.git;
in {
  options.features.shell.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.shell.enable && true;
    };
    lfs = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.git];

    home-manager.users.cloudburst = {
      programs.git = {
        enable = true;
        lfs.enable = cfg.lfs;
        settings = {
          user = {
            name = "Cloudburst";
            email = "18114966+C10udburst@users.noreply.github.com";
          };
          init = {
            defaultBranch = "master";
          };
        };
      };

      home.packages = [pkgs.git-filter-repo];
    };
  };
}
