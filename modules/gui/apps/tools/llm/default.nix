{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.tools.llm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.apps.tools.enable && true;
    };
  };
}
