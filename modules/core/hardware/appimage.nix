{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.appimage = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable && cfg.appimage) {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
