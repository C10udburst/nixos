{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.locale.pl;
in {
  options.features.core.locale.pl = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.core.enable && config.features.core.locale.enable) && true;
  };

  config = lib.mkIf cfg {
    time.timeZone = "Europe/Warsaw";
    i18n.defaultLocale = "pl_PL.UTF-8";
    i18n.supportedLocales = [
      "pl_PL.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pl_PL.UTF-8";
      LC_IDENTIFICATION = "pl_PL.UTF-8";
      LC_MEASUREMENT = "pl_PL.UTF-8";
      LC_MONETARY = "pl_PL.UTF-8";
      LC_NAME = "pl_PL.UTF-8";
      LC_NUMERIC = "pl_PL.UTF-8";
      LC_PAPER = "pl_PL.UTF-8";
      LC_TELEPHONE = "pl_PL.UTF-8";
      LC_TIME = "pl_PL.UTF-8";
    };
    console.keyMap = "pl2";
  };
}
