{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
  webCfg = config.features.server.web;
  baseDomain = webCfg.core.baseDomain or "example.com";
  rawApps = webCfg.core._apps or [];
  sortedApps = lib.sort (a: b: a.name < b.name) rawApps;

  appCards = lib.concatStringsSep "\n" (
    map (
      app: let
        aliases = app.aliases or [];
        sortedAliases = lib.sort (a: b: a < b) aliases;
        aliasTags = lib.concatStringsSep "\n" (
          map (
            alias: ''
              <a class="alias-tag" href="https://${alias}.${baseDomain}">
                <span class="alias-name">${alias}</span>
              </a>
            ''
          )
          sortedAliases
        );
      in ''
        <li class="app-card">
          <div class="card-main">
            <a class="primary-link" href="https://${app.name}.${baseDomain}">
              <span class="name">${app.name}</span><span class="domain">.${baseDomain}</span>
            </a>
          </div>
          ${lib.optionalString (aliases != []) ''
          <div class="aliases-section">
            <span class="aliases-label">Aliases</span>
            <div class="alias-tags">
              ${aliasTags}
            </div>
          </div>
        ''}
        </li>
      ''
    )
    sortedApps
  );

  aliasesHtml = pkgs.writeText "aliases.html" ''
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1"/>
      <title>Web Aliases - ${baseDomain}</title>
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
        .header {
          text-align: center;
          margin-bottom: 16px;
        }
        h1 {
          margin: 0 0 8px 0;
          font-size: 22px;
          letter-spacing: 0.5px;
        }
        .back-link {
          font-size: 13px;
          color: #888;
          text-decoration: none;
          transition: color 0.15s ease;
        }
        .back-link:hover {
          color: #4aa3ff;
          text-decoration: underline;
        }
        .search-box {
          width: 100%;
          max-width: 560px;
          margin-bottom: 14px;
        }
        .search-box input {
          width: 100%;
          box-sizing: border-box;
          padding: 12px 16px;
          background: #1f2128;
          border: 1px solid rgba(255, 255, 255, 0.08);
          border-radius: 12px;
          color: #e0e0e0;
          font-size: 14px;
          outline: none;
          transition: border-color 0.15s ease, box-shadow 0.15s ease;
        }
        .search-box input:focus {
          border-color: #4aa3ff;
          box-shadow: 0 0 0 2px rgba(74, 163, 255, 0.2);
        }
        ul {
          list-style: none;
          padding: 0;
          margin: 0;
          width: 100%;
          max-width: 560px;
        }
        li.app-card {
          background: #1f2128;
          margin: 8px 0;
          border-radius: 12px;
          padding: 14px 18px;
          box-shadow: 0 4px 12px rgba(0,0,0,0.35);
          transition: transform 0.15s ease, background 0.15s ease;
        }
        li.app-card:hover {
          transform: scale(1.01);
          background: #272b35;
        }
        .card-main {
          display: flex;
          align-items: baseline;
          justify-content: space-between;
        }
        .primary-link {
          text-decoration: none;
          color: #4aa3ff;
          font-weight: 500;
        }
        .primary-link:hover .name {
          text-decoration: underline;
        }
        .name {
          font-family: monospace;
          font-size: 16px;
        }
        .domain {
          font-family: monospace;
          font-size: 13px;
          color: #888;
        }
        .aliases-section {
          margin-top: 10px;
          padding-top: 8px;
          border-top: 1px solid rgba(255, 255, 255, 0.06);
          display: flex;
          align-items: center;
          flex-wrap: wrap;
          gap: 6px;
        }
        .aliases-label {
          font-size: 11px;
          text-transform: uppercase;
          letter-spacing: 0.6px;
          color: #888;
          font-weight: 600;
          margin-right: 4px;
        }
        .alias-tags {
          display: flex;
          flex-wrap: wrap;
          gap: 6px;
        }
        .alias-tag {
          display: inline-block;
          background: #16181f;
          border: 1px solid rgba(255, 255, 255, 0.08);
          border-radius: 6px;
          padding: 3px 8px;
          text-decoration: none;
          color: #a0c0e0;
          font-family: monospace;
          font-size: 13px;
          transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
        }
        .alias-tag:hover {
          background: #222734;
          border-color: #4aa3ff;
          color: #ffffff;
        }
        .footer {
          margin-top: 24px;
          font-size: 12px;
          color: #888;
          text-align: center;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Web Service Aliases</h1>
        <a class="back-link" href="/">← CGI Directory</a>
      </div>
      <div class="search-box">
        <input type="text" id="filter" placeholder="Filter services or aliases..." autofocus/>
      </div>
      <ul>
        ${appCards}
      </ul>
      <div class="footer">cgi.${baseDomain}</div>
      <script>
        const input = document.getElementById('filter');
        if (input) {
          input.addEventListener('input', () => {
            const query = input.value.toLowerCase().trim();
            document.querySelectorAll('.app-card').forEach(card => {
              const text = card.textContent.toLowerCase();
              card.style.display = text.includes(query) ? "" : "none";
            });
          });
        }
      </script>
    </body>
    </html>
  '';
in {
  options.features.server.web.cgi.aliases = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable && true;
  };

  config = lib.mkIf (cfg.enable && config.features.server.web.cgi.aliases) {
    features.server.web.cgi.scripts.aliases.script = pkgs.writeShellScript "aliases" ''
      printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
      exec ${pkgs.coreutils}/bin/cat ${aliasesHtml}
    '';
  };
}
