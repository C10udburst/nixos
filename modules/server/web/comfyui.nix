{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.comfyui;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};

  # ComfyUI can take a while to come up on first access, so the failed proxy
  # attempt is answered with a page that keeps reloading until it is reachable.
  startingPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1"/>
      <meta http-equiv="refresh" content="5"/>
      <title>ComfyUI is starting</title>
      <style>
        body {
          margin: 0;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: #12131a;
          color: #e0e0e0;
          font-family: Arial, sans-serif;
          text-align: center;
        }
        .spinner {
          width: 28px;
          height: 28px;
          margin: 0 auto 18px;
          border: 3px solid rgba(255, 255, 255, 0.15);
          border-top-color: #4aa3ff;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        }
        h1 { font-size: 20px; margin: 0 0 8px 0; }
        p { font-size: 13px; color: #888; margin: 0; }
        @keyframes spin { to { transform: rotate(360deg); } }
      </style>
    </head>
    <body>
      <div>
        <div class="spinner"></div>
        <h1>ComfyUI is starting up</h1>
        <p>Retrying every 5 seconds until the service answers.</p>
      </div>
    </body>
    </html>
  '';
in {
  options.features.server.web.comfyui = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    webHelper.mkWebApp {
      name = "comfyui";
      aliases = [
        "comfy"
      ];
      upstream = "llm.wilkins.pl.eu.org:8188";
      cors = true;
      extraErrorsConfig = ''
        @starting {
          expression `{err.status_code} in [502, 503, 504]`
          method GET
        }
        handle @starting {
          root * ${startingPage}
          rewrite * /index.html
          header Cache-Control "no-store"
          file_server
        }
      '';
    }
  );
}
