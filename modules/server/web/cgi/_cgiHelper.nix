{lib, ...}: {
  # Helper to define a CGI script under features.server.web.cgi.scripts
  # Usage:
  #   cgiHelper.mkCgiScript "name" <script>
  # or:
  #   cgiHelper.mkCgiScript { name = "foo"; script = <script>; }
  mkCgiScript = arg:
    if builtins.isString arg
    then
      script: {
        features.server.web.cgi.scripts.${arg}.script = script;
      }
    else {
      features.server.web.cgi.scripts.${arg.name}.script = arg.script;
    };
}
