{
  config,
  lib,
  ...
}: {
  options.features.compat = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
}
