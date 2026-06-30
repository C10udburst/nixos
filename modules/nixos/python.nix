{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.python;
in {
  options.systemSettings.python = {
    enable = lib.mkEnableOption "Enable Python data science packages and PyTorch";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.python3.withPackages (ps:
        with ps; [
          requests
          pandas
          torch
        ]))
    ];
  };
}
