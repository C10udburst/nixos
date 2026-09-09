{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.apps.tools.llm.ollama;
  llmEnabled = config.features.gui.apps.tools.llm.enable;
  isNvidia = config.features.core.hardware.nvidia or false;
in {
  options.features.gui.apps.tools.llm.ollama = lib.mkOption {
    type = lib.types.bool;
    default = llmEnabled && false;
  };

  config = lib.mkIf cfg {
    services.ollama = {
      enable = true;
      acceleration =
        if isNvidia
        then "cuda"
        else null;
    };
  };
}
