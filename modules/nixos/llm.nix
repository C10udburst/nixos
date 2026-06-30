{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.llm;
in {
  options.systemSettings.llm = {
    enable = lib.mkEnableOption "Enable LLM agents and tools (Antigravity)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
      inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
    ];
  };
}
