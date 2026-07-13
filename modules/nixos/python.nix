{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.python;
  nvidiaEnabled = config.systemSettings.nvidia.enable;

  # Use the CUDA-enabled torch when nvidia is on, plain CPU torch otherwise
  torchPkg =
    if nvidiaEnabled
    then pkgs.python3Packages.torch #WithCuda
    else pkgs.python3Packages.torch;

  pythonPkg = pkgs.python3.withPackages (ps:
    with ps; [
      requests
      pandas
      torchPkg
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
