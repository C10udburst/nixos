{
  config,
  lib,
  ...
}: {
  options.features.shell.utils = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.shell.enable
        then true
        else false;
    };
  };
}
