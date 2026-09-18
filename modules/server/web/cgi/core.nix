{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
in {
  config = lib.mkIf cfg.enable {
    features.server.web.cgi.scripts = {
      echo.script = pkgs.writeShellScript "echo" ''
        exec ${pkgs.python3}/bin/python3 ${./_scripts/echo.py} "$@"
      '';

      bing-img.script = pkgs.writeShellScript "bing-img" ''
        exec ${pkgs.python3}/bin/python3 ${./_scripts/bing-img.py} "$@"
      '';
    };
  };
}
