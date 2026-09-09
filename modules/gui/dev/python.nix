{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled = config.features.gui.dev.enable;
  cfg = config.features.gui.dev.python;
  nvidiaEnabled = config.features.core.hardware.nvidia or false;

  torchPkg =
    if nvidiaEnabled
    then pkgs.python3Packages.torch
    else pkgs.python3Packages.torch;

  selectedPackages = ps:
    (lib.optionals cfg.dataScience (
      with ps; [
        numpy
        pandas
        scipy
        matplotlib
        scikit-learn
        ipython
      ]
    ))
    ++ (lib.optionals cfg.ai [torchPkg])
    ++ (lib.optionals cfg.utils (
      with ps; [
        requests
        pypdf
        tkinter
      ]
    ));

  pythonPkg = pkgs.python3.withPackages selectedPackages;
in {
  options.features.gui.dev.python = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = devEnabled && true;
    };
    dataScience = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    ai = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    utils = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pythonPkg
    ];

    environment.sessionVariables = {
      PYTHONPATH = "${pythonPkg}/${pythonPkg.sitePackages}";
    };
  };
}
