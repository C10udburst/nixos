{
  config,
  lib,
  ...
}: let
  cfg = config.features.compat;
in {
  options.features.compat.appimage = lib.mkOption {
    type = lib.types.bool;
    default = config.features.compat.enable && false;
  };

  config = lib.mkIf cfg.appimage {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
