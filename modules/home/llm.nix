{
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.homeSettings.llm;
in {
  imports = [
    inputs.pi-agent.homeModules.default
  ];

  options.homeSettings.llm = {
    enable = lib.mkEnableOption "Enable LLM agent tools (Pi Coding Agent)";
  };

  config = lib.mkIf cfg.enable {
    programs.pi-coding-agent.enable = true;
  };
}
