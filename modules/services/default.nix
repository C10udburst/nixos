{lib, ...}: {
  options.features.services = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
}
