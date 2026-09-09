{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.brave = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.apps.enable
        then true
        else false;
    };
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    extraCliFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };
}
