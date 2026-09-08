{
  config,
  lib,
  ...
}: {
  options.features.core.hardware = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
    mobile = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    slow = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
