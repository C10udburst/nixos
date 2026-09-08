{lib, ...}: {
  options.features.gui.apps.editors.media = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
