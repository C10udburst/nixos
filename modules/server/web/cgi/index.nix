{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";

  scriptCards = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: _s: ''
      <li>
        <a href="/${name}">
          <span class="name">${name}</span>
        </a>
      </li>
    '')
    cfg.scripts
  );

  indexPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1"/>
      <title>CGI Directory - cgi.${baseDomain}</title>
      <style>
        body {
          margin: 0;
          font-family: Arial, sans-serif;
          background: #12131a;
          color: #e0e0e0;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 20px;
        }
        h1 {
          margin-bottom: 12px;
          font-size: 22px;
          letter-spacing: 0.5px;
        }
        ul {
          list-style: none;
          padding: 0;
          width: 100%;
          max-width: 520px;
        }
        li {
          background: #1f2128;
          margin: 8px 0;
          border-radius: 12px;
          box-shadow: 0 4px 12px rgba(0,0,0,0.35);
          transition: transform 0.15s ease, background 0.15s ease;
        }
        a {
          display: block;
          text-decoration: none;
          color: #4aa3ff;
          padding: 14px 18px;
          font-weight: 500;
          border-radius: 12px;
        }
        .name {
          font-family: monospace;
          font-size: 15px;
        }
        li:hover {
          transform: scale(1.02);
          background: #272b35;
        }
        a:hover {
          text-decoration: underline;
        }
        .footer {
          margin-top: 24px;
          font-size: 12px;
          color: #888;
        }
      </style>
    </head>
    <body>
      <h1>CGI Directory Listing</h1>
      <ul>
        ${scriptCards}
      </ul>
      <div class="footer">cgi.${baseDomain}</div>
    </body>
    </html>
  '';
in {
  config = lib.mkIf cfg.enable {
    features.server.web.cgi.indexHtml = lib.mkDefault indexPage;
  };
}
