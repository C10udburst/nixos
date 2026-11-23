{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.llm.pi.web;
  piCfg = config.features.shell.utils.llm.pi;

  # pi-web embeds pi's own libraries and spawns the `pi` binary in its
  # terminals, so it gets the raw package rather than the wrapped
  # programs.pi.coding-agent one: that wrapper appends the desktop agent's
  # --extension flags and merges its settings on every invocation.
  piPackage = config.programs.pi.coding-agent.package;

  piWeb = import ./_pi-web.nix {
    inherit pkgs;
    src = inputs.pi-web;
  };

  # Shared EVO-X2 gateway catalog, same source as the terminal agent's.
  evoX2 = import ../_evo-x2.nix;
  # Shared extension sources and gateway URLs (pi, omp and pi-web all read it).
  ext = import ./_extensions.nix;
  modelsJson = pkgs.writeText "pi-web-models.json" evoX2.piJson;

  # Starting point for the separate agent directory: the settings the terminal
  # agent declares, without ever touching ~/.pi/agent.
  baseSettings = pkgs.writeText "pi-web-base-settings.json" (
    builtins.toJSON config.programs.pi.coding-agent.settings
  );

  # pi-web has no --extension flag; it loads pi's resources from settings.json,
  # so the plugin paths are handed to the wrapper as JSON. Each plugin is
  # copied out first: settings.json must name a store path of its own, not a
  # file inside the checked out flake.
  plugins = pkgs.writeText "pi-web-plugins.json" (
    builtins.toJSON (
      [ (pkgs.copyPathToStore ext.extensions.systemPrompt) ]
      ++ lib.optionals (piCfg.litellmProxy != null) [(pkgs.copyPathToStore ext.extensions.litellm)]
      ++ lib.optionals (piCfg.googleProxy != null) [(pkgs.copyPathToStore ext.extensions.googleSearch)]
      ++ lib.optionals (piCfg.reservationsApi != null) [(pkgs.copyPathToStore ext.extensions.queue)]
    )
  );

  piWebWrapper = pkgs.writeShellApplication {
    name = "pi-web";
    runtimeInputs = [
      pkgs.jq
      piPackage
    ];

    text = ''
      export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/web}"
      export PI_WEB_SKIP_VERSION_CHECK=1
      export PI_WEB_IDLE_TIMEOUT_MS=0
      ${lib.optionalString (cfg.allowedHosts != []) ''
        export PI_WEB_ALLOWED_HOSTS=${lib.escapeShellArg (lib.concatStringsSep "," cfg.allowedHosts)}
      ''}
      ${lib.optionalString (piCfg.litellmProxy != null) ''
        export LITELLM_API_BASE=${lib.escapeShellArg piCfg.litellmProxy}
      ''}
      ${lib.optionalString (piCfg.googleProxy != null) ''
        export GOOGLE_SEARCH_API_BASE=${lib.escapeShellArg piCfg.googleProxy}
      ''}
      ${lib.optionalString (piCfg.reservationsApi != null) ''
        export EVO_X2_RESERVATIONS_URL=${lib.escapeShellArg piCfg.reservationsApi}
        export EVO_X2_QUEUE_DOMAIN=${lib.escapeShellArg ext.gatewayDomain}
      ''}

      agent_dir="$PI_CODING_AGENT_DIR"
      mkdir -p "$agent_dir"

      if [ -e "$agent_dir/models.json" ]; then
        rm "$agent_dir/models.json"
      fi
      install -m 0600 ${modelsJson} "$agent_dir/models.json"

      # pi-web loads pi's plugins through settings.json, so the declared plugin
      # paths are merged in before the server starts. Both merges only fill
      # gaps: settings the user changed stay changed, and a plugin already
      # listed is never added twice.
      settings="$agent_dir/settings.json"
      [ -e "$settings" ] || printf '%s\n' '{}' > "$settings"

      tmp="$(mktemp "$agent_dir/settings.json.XXXXXX")"
      jq --slurpfile base ${baseSettings} --slurpfile plugins ${plugins} '
        (.extensions // []) as $loaded
        | ($base[0] * .)
        | .extensions = ($loaded + ($plugins[0] - $loaded))
      ' "$settings" > "$tmp"
      chmod 0600 "$tmp"
      if cmp -s "$tmp" "$settings"; then
        rm -f "$tmp"
      else
        mv "$tmp" "$settings"
      fi

      exec ${piWeb}/bin/pi-web -H 0.0.0.0 -p ${toString cfg.port} --no-open "$@"
    '';
  };
in {
  options.features.shell.utils.llm.pi.web = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = piCfg.enable && false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 30141;
    };

    # Extra exact hostnames accepted by the proxy, for a reverse proxy or a
    # DNS name in front of the bound address.
    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        pi-web = {
          url = "github:agegr/pi-web";
          flake = false;
        };
      };
    }

    (lib.mkIf cfg.enable {
      home-manager.users.cloudburst = {
        home.packages = [piWebWrapper];

        systemd.user.services.pi-web = {
          Unit = {
            Description = "Pi Web UI for the pi coding agent";
            After = ["network-online.target"];
          };

          Service = {
            Type = "simple";
            ExecStart = "${lib.getExe piWebWrapper}";
            Restart = "on-failure";
            RestartSec = "5";
          };

          Install.WantedBy = ["default.target"];
        };
      };
    })
  ];
}
