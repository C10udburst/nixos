{lib, ...}: {
  options.features.gui.dev = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
