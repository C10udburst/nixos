{
  config,
  lib,
  ...
}: let
  cfg = config.features.services;
in {
  options.features.services = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
}
