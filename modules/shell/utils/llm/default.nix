{
  config,
  lib,
  ...
}: {
  options.features.shell.utils.llm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.shell.utils.enable && true;
    };
  };
}
