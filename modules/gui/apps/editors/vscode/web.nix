{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.editors.vscode.web;
  vscodeCfg = config.features.gui.apps.editors.vscode;

  # The very same extensions, toolchain and settings as the desktop app. The
  # nix-vscode-extensions input is declared in ./default.nix, which also keeps
  # the registry alive for this module.
  ext = import ./_extensions.nix {inherit config lib pkgs;};
  userSettings = import ./_settings.nix;

  settingsJson = pkgs.writeText "openvscode-server-settings.json" (
    builtins.toJSON userSettings
  );

  # openvscode-server accepts one flat --extensions-dir, while every
  # nix-vscode-extensions derivation ships its payload under
  # `$out/share/vscode/extensions/<publisher>.<name>`. Flattening that with
  # plain symlinks is not enough: the server rewrites the `__metadata` block of
  # every manifest that carries one — jupyter's does, straight from the vsix —
  # and a manifest inside the read-only store answers EROFS. So the declared set
  # is rebuilt as one directory whose payloads are still links into their own
  # derivations while each manifest is a copy with the block removed, the shape
  # the server leaves untouched.
  extensionsDir =
    pkgs.runCommand "vscodium-server-extensions" {
      nativeBuildInputs = [pkgs.jq];
    } (
      ''
        mkdir -p $out
      ''
      + lib.concatMapStringsSep "\n" (e: ''
        for extension in ${e}/share/vscode/extensions/*; do
          name="$(basename "$extension")"
          mkdir -p "$out/$name"
          find "$extension" -mindepth 1 -maxdepth 1 -exec ln -s '{}' "$out/$name/" ';'
          rm -f "$out/$name/package.json"
          jq 'del(.__metadata)' "$extension/package.json" > "$out/$name/package.json"
        done
      '')
      ext.vscodiumServer.extensions
    );

  # Without the desktop app there is no `code` on PATH at all, so give the
  # browser session the same spelling: `code .` resolves the argument to an
  # absolute path and prints the deep link, which every terminal renders as a
  # clickable URL. A file argument links the folder holding it, the workbench
  # only takes folders.
  codeLink = pkgs.writeShellApplication {
    name = "code";

    runtimeInputs = [pkgs.coreutils];

    text = ''
      base="''${CODE_WEB_URL:-https://${cfg.domain}}"

      # stdout carries the link alone, so the usage goes to stderr
      case "''${1:-}" in
        -h | --help)
          printf 'usage: code [PATH]\n\n' >&2
          printf 'Print the link that opens PATH in the browser editor of %s, i.e.\n%s/?folder=<absolute PATH>. PATH defaults to the current directory\nand is always written out absolute, so a link printed on a remote shell\ncan be followed locally; a file links the folder holding it, the work-\nbench takes folders. CODE_WEB_URL overrides the base.\n' "$base" "$base" >&2
          exit 0
          ;;
      esac

      # the first argument that is not a flag, the rest is the server's business
      target=""
      for arg in "$@"; do
        case "$arg" in
          -*) continue ;;
        esac
        if [ -z "$target" ]; then
          target="$arg"
        fi
      done

      # -m: paths which do not exist yet are still worth a link
      path="$(realpath -m -- "''${target:-$PWD}")"
      if [ -f "$path" ]; then
        path="$(dirname "$path")"
      fi

      # only the characters a query string cannot carry, the workbench decodes
      path="''${path//%/%25}"
      path="''${path// /%20}"
      path="''${path//#/%23}"
      path="''${path//'?'/%3F}"
      path="''${path//&/%26}"

      printf '%s/?folder=%s\n' "''${base%/}" "$path"
    '';
  };

  server = pkgs.writeShellApplication {
    name = "openvscode-server-web";

    # PATH of the server itself, and therefore of every extension host it
    # spawns: language servers, formatters and the toolchain the integrated
    # terminal sees.
    runtimeInputs = [pkgs.openvscode-server] ++ ext.vscodiumServer.packages;

    text = ''
      state_dir="''${OPENVSCODE_WEB_DIR:-$HOME/.local/state/openvscode-server-web}"
      user_data="$state_dir/user-data"
      extensions_dir="$state_dir/extensions"

      mkdir -p "$user_data/User" "$extensions_dir" "$state_dir/server-data" "$user_data/Machine"

      ${lib.optionalString (ext.vscodiumServer.extensions != []) ''
        # refresh the declared set: links of a previous generation go, real
        # directories installed from the UI stay
        find "$extensions_dir" -mindepth 1 -maxdepth 1 -type l -delete
        ln -sfn ${extensionsDir}/* "$extensions_dir/"
      ''}

      # the shared settings, laid down as the whole file before the server
      # starts: the declared set is authoritative, so whatever the browser wrote
      # is gone at the next start
      settings="$user_data/Machine/settings.json"
      if ! cmp -s ${settingsJson} "$settings"; then
        tmp="$(mktemp "$user_data/Machine/settings.json.XXXXXX")"
        cat ${settingsJson} > "$tmp"
        chmod 0644 "$tmp"
        mv "$tmp" "$settings"
      fi

      # Bound to every interface so the reverse proxy can reach it, hence no
      # connection token: the vhost of features.server.web.code is the
      # authentication boundary.
      exec openvscode-server \
        --host 0.0.0.0 \
        --port ${toString cfg.port} \
        --user-data-dir "$user_data" \
        --server-data-dir "$state_dir/server-data" \
        --extensions-dir "$extensions_dir" \
        --telemetry-level off \
        --without-connection-token \
        --accept-server-license-terms \
        "$@"
    '';
  };
in {
  options.features.gui.apps.editors.vscode.web = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = vscodeCfg.enable && false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 30142;
    };

    # Where the server is published from: the vhost of a host running caddy in
    # front of this one, not necessarily a vhost of this host.
    domain = lib.mkOption {
      type = lib.types.str;
      default = "code.brix0.wilkins.pl.eu.org";
    };
  };

  config = lib.mkIf cfg.enable {
    # pkgs.vscode-marketplace comes from the overlay, so it has to be applied
    # even on a headless host where ./default.nix stays disabled.
    nixpkgs.overlays = [
      (inputs.nix-vscode-extensions.overlays.default or (_: _: {}))
      ext.overlay
    ];

    home-manager.users.cloudburst = {
      # while the desktop app is enabled it owns the `code` name
      home.packages = [server] ++ lib.optionals (!vscodeCfg.enable) [codeLink];

      systemd.user.services.openvscode-server-web = {
        Unit = {
          Description = "VSCodium in the browser (openvscode-server)";
          After = ["network-online.target"];
        };

        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe server}";
          Restart = "on-failure";
          RestartSec = "5";

          # The Jupyter extension sweeps /tmp when it initialises: inside the
          # shared /tmp that walk reaches other people's systemd-private-*
          # directories, which it can neither read nor own, and the log fills
          # with EACCES stack traces. PrivateTmp gives it an empty one.
          PrivateTmp = "yes";
        };

        Install.WantedBy = ["default.target"];
      };
    };
  };
}
