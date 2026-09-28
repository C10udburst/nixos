{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.llm.ollama;
  isNvidia = config.features.core.hardware.nvidia or false;
in {
  options.features.server.llm.ollama = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.llm.enable && false;
    };
    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package =
        if isNvidia
        then pkgs.ollama-cuda
        else pkgs.ollama;
      loadModels = cfg.models;
      host = "0.0.0.0";
      openFirewall = true;
    };
  };
}
