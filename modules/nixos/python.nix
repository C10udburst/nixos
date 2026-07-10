{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.python;

  pythonPkg = pkgs.python3.withPackages (ps:
    with ps; [
      requests
      pandas
      torch
      numpy
      ipython
      matplotlib
      scipy
      scikit-learn
      pypdf
    ]);
in {
  options.systemSettings.python = {
    enable = lib.mkEnableOption "Enable Python data science packages and PyTorch";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pythonPkg
    ];

    # ensure pycharm finds the correct python interpreter
    environment.sessionVariables = {
      PYTHONPATH = "${pythonPkg}/${pythonPkg.sitePackages}";
    };
  };
}
