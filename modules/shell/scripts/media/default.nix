{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.scripts.media;
  icat = pkgs.writeShellScriptBin "icat" (builtins.readFile ./_icat.sh);
  palette = pkgs.writeShellScriptBin "palette" (builtins.readFile ./_palette.sh);
  video8mb = pkgs.writers.writePython3Bin "video8mb" {} (builtins.readFile ./_video8mb.py);
  datauri = pkgs.writeShellScriptBin "datauri" (builtins.readFile ./_datauri.sh);
in {
  options.features.shell.scripts.media = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.shell.enable && config.features.shell.scripts.enable) && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [
      icat
      palette
      video8mb
      datauri
      pkgs.chafa
      pkgs.libsixel
    ];
  };
}
