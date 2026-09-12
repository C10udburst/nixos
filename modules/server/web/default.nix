{
  config,
  lib,
  ...
}: {
  options.features.server.web = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.enable && false;
    };
    storage = lib.mkOption {
      type = lib.types.str;
      default = "/opt";
    };
  };
}
