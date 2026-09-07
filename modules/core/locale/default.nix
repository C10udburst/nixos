{
  config,
  lib,
  ...
}: {
  options.features.core.locale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
  };
}
