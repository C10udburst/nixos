{
  config,
  lib,
  ...
}: {
  options.features.server = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
