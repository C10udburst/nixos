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
  # Extension groups and gateway URLs, shared with omp and the organizer pi
  # through the llm/pi/extensions/default.nix module.
  ext = piCfg.extensions;
  # The prompt the terminal agent runs on, same text for these sessions: pi-web
  # points PI_CODING_AGENT_DIR at ~/.pi/web and reads SYSTEM.md from there.
  prompt = piCfg.prompt;
  modelsJson = pkgs.writeText "pi-web-models.json" evoX2.piJson;

  # Starting point for the separate agent directory: the settings the terminal
  # agent declares, without ever touching ~/.pi/agent.
  baseSettings = pkgs.writeText "pi-web-base-settings.json" (
    builtins.toJSON config.programs.pi.coding-agent.settings
  );

  # pi-web has no --extension flag; it loads pi's plugins from settings.json,
  # so the plugin paths are handed to the wrapper as JSON. Each plugin is
  # copied out first: settings.json must name a store path of its own, not a
  # file inside the checked out flake.
  plugins = pkgs.writeText "pi-web-plugins.json" (
    builtins.toJSON (map pkgs.copyPathToStore cfg.plugins)
  );

  # The npm/git sources of settings.json, the other place pi loads resources
  # from and the one the web UI's plugin page writes.
  packages = pkgs.writeText "pi-web-packages.json" (builtins.toJSON cfg.packages);

  # The gateway URLs the loaded extensions read, one export per line.
  exports = lib.concatStrings (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") ext.environment
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
      ${exports}
      ${lib.optionalString (cfg.allowedHosts != []) ''
        export PI_WEB_ALLOWED_HOSTS=${lib.escapeShellArg (lib.concatStringsSep "," cfg.allowedHosts)}
      ''}

      agent_dir="$PI_CODING_AGENT_DIR"
      mkdir -p "$agent_dir"

      if [ -e "$agent_dir/models.json" ]; then
        rm "$agent_dir/models.json"
      fi
      install -m 0600 ${modelsJson} "$agent_dir/models.json"

      # settings.json is both how pi-web is handed its plugins and what the web
      # UI writes: its plugin page appends npm/git sources to `packages` and its
      # resource toggles prefix `extensions` entries with "+" and "-". So the two
      # plugin keys are rewritten from nix on every start, while the rest of the
      # settings only get filled in and stay as the UI left them.
      settings="$agent_dir/settings.json"

      # A truncated or hand-broken settings.json must not crash-loop the unit.
      user="$(jq -c 'if type == "object" then . else {} end' "$settings" 2>/dev/null || printf '%s' '{}')"

      tmp="$(mktemp "$agent_dir/settings.json.XXXXXX")"
      jq -n --argjson user "$user" \
        --slurpfile base "${baseSettings}" \
        --slurpfile plugins "${plugins}" \
        --slurpfile packages "${packages}" '
          ($base[0] * $user)
          | .extensions = $plugins[0]
          | .packages = $packages[0]
        ' > "$tmp"
      chmod 0600 "$tmp"
      cmp -s "$tmp" "$settings" || mv "$tmp" "$settings"
      rm -f "$tmp"

      exec ${piWeb}/bin/pi-web -H 0.0.0.0 -p ${toString cfg.port} --no-open "$@"
    '';
  };
in {
  options.features.shell.utils.llm.pi.web = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = piCfg.enable && false;
    };

    # The plugins this server loads, and the only ones it ever loads: the wrapper
    # overwrites both plugin keys of settings.json on every start, so whatever
    # the web UI installed or toggled in them is gone again on the next restart.
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = ext.piAgentExtensions;
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
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

        # Not the wrapper's own file: pi-web loads its prompt from the agent
        # directory it is handed, the same way the terminal agent does.
        home.file.".pi/web/SYSTEM.md" = lib.mkIf prompt.enable {
          source = prompt.shared.mkSystemPrompt {name = "pi-web";};
          force = true;
        };

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
