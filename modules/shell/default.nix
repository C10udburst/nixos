{
  config,
  lib,
  ...
}: {
  options.features.shell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
}
