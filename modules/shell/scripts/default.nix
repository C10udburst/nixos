{
  config,
  lib,
  ...
}: {
  options.features.shell.scripts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.shell.enable
        then true
        else false;
    };
  };
}
