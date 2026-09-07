{
  config,
  lib,
  ...
}: let
  cfg = config.features.compat;
in {
  options.features.compat.appimage = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.compat.enable && cfg.appimage) {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
