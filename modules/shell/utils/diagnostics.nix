{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.diagnostics;
  utilsEnabled = config.features.shell.enable && config.features.shell.utils.enable;
in {
  options.features.shell.utils.diagnostics = lib.mkOption {
    type = lib.types.bool;
    default =
      if utilsEnabled
      then true
      else false;
  };

  config = lib.mkIf (utilsEnabled && cfg) {
    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
    ];
  };
}
