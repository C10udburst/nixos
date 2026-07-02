{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.git;
in {
  options.homeSettings.git = {
    enable = lib.mkEnableOption "Enable git configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
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

    home.packages = with pkgs; [
      git-filter-repo
    ];
  };
}
