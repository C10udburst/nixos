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

  server = pkgs.writeShellApplication {
    name = "openvscode-server-web";

    # PATH of the server itself, and therefore of every extension host it
    # spawns: language servers, formatters and the toolchain the integrated
    # terminal sees.
    runtimeInputs = [pkgs.openvscode-server pkgs.jq] ++ ext.vscodiumServer.packages;

    text = ''
      state_dir="''${OPENVSCODE_WEB_DIR:-$HOME/.local/state/openvscode-server-web}"
      user_data="$state_dir/user-data"
      extensions_dir="$state_dir/extensions"

      mkdir -p "$user_data/User" "$extensions_dir" "$state_dir/server-data"

      ${lib.optionalString (ext.vscodiumServer.extensions != []) ''
        # refresh the declared set: links of a previous generation go, real
        # directories installed from the UI stay
        find "$extensions_dir" -mindepth 1 -maxdepth 1 -type l -delete
        ln -sfn ${extensionsDir}/* "$extensions_dir/"
      ''}

      # the shared settings, merged in before the server starts: settings the
      # user changed in the browser stay changed, declared settings that are
      # missing get added
      settings="$user_data/User/settings.json"
      [ -e "$settings" ] || printf '%s\n' '{}' > "$settings"

      tmp="$(mktemp "$user_data/User/settings.json.XXXXXX")"
      jq --slurpfile base ${settingsJson} '$base[0] * .' "$settings" > "$tmp"
      chmod 0644 "$tmp"
      if cmp -s "$tmp" "$settings"; then
        rm -f "$tmp"
      else
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
  };

  config = lib.mkIf cfg.enable {
    # pkgs.vscode-marketplace comes from the overlay, so it has to be applied
    # even on a headless host where ./default.nix stays disabled.
    nixpkgs.overlays = [
      (inputs.nix-vscode-extensions.overlays.default or (_: _: {}))
      ext.overlay
    ];

    home-manager.users.cloudburst = {
      home.packages = [server];

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
