{
  config,
  lib,
  ...
}: {
  options.features.server.llm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.enable && false;
    };
  };
}
