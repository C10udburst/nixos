{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.diagnostics;
  utilsEnabled = config.features.shell.utils.enable;
in {
  options.features.shell.utils.diagnostics = lib.mkOption {
    type = lib.types.bool;
    default = utilsEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
    ];
  };
}
