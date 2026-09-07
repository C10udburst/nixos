{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.apps.tools.llm.ollama;
  llmEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.tools.enable
    && config.features.gui.apps.tools.llm.enable;
  isNvidia = config.features.core.hardware.nvidia or false;
in {
  options.features.gui.apps.tools.llm.ollama = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (llmEnabled && cfg) {
    services.ollama = {
      enable = true;
      acceleration =
        if isNvidia
        then "cuda"
        else null;
    };
  };
}
