{
  config,
  lib,
  ...
}: {
  options.features.gui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
}
