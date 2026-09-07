{
  config,
  lib,
  pkgs,
  ...
}: let
  serverEnabled = config.features.server.enable;
  cfg = config.features.server.westonRdp;

  westonIni = pkgs.writeText "weston.ini" ''
    [core]
    shell=kiosk-shell.so

    [shell]
    quit-when-apps-close=true
  '';

  countryCode = let
    locale = config.i18n.defaultLocale or "en_US.UTF-8";
    parts = lib.splitString "_" locale;
  in
    if lib.length parts > 1
    then lib.head (lib.splitString "." (lib.elemAt parts 1))
    else "US";
in {
  options.features.server.westonRdp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "cloudburst";
    };

    tlsCert = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/weston-rdp/tls.crt";
    };

    tlsKey = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/weston-rdp/tls.key";
    };

    gskRenderer = lib.mkOption {
      type = lib.types.str;
      default = "ngl";
    };

    windowManager = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.driftwm}/bin/driftwm";
    };
  };

  config = lib.mkIf (serverEnabled && cfg.enable) {
    networking.firewall.allowedTCPPorts = [3389];

    users.users.${cfg.user}.linger = true;

    systemd.tmpfiles.rules = [
      "d /var/lib/weston-rdp 0700 ${cfg.user} users - -"
    ];

    systemd.services.weston-rdp = {
      description = "Weston RDP remote desktop service running ${cfg.windowManager}";
      after = ["network.target" "systemd-user-sessions.service"];
      wantedBy = ["multi-user.target"];

      preStart = ''
        mkdir -p "$(dirname "${cfg.tlsCert}")"
        mkdir -p "$(dirname "${cfg.tlsKey}")"

        if [ ! -f "${cfg.tlsCert}" ] || [ ! -f "${cfg.tlsKey}" ]; then
          echo "Generating self-signed RDP TLS certificate and key..."
          ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${cfg.tlsKey}" \
            -out "${cfg.tlsCert}" \
            -subj "/C=${countryCode}/CN=Weston RDP Server"

          chmod 600 "${cfg.tlsKey}"
          chmod 644 "${cfg.tlsCert}"
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";

        ExecStart = pkgs.writeShellScript "start-weston-rdp" ''
          USER_UID=$(${pkgs.coreutils}/bin/id -u "${cfg.user}")
          export HOME="/home/${cfg.user}"
          export XDG_RUNTIME_DIR="/run/user/$USER_UID"
          export GSK_RENDERER="${cfg.gskRenderer}"
          export PATH="/run/wrappers/bin:/home/${cfg.user}/.nix-profile/bin:/etc/profiles/per-user/${cfg.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:${lib.makeBinPath [pkgs.weston]}"

          mkdir -p "$XDG_RUNTIME_DIR"
          chmod 700 "$XDG_RUNTIME_DIR"

          ${pkgs.weston}/bin/weston \
            --backend=rdp \
            --address="0.0.0.0" \
            --port=3389 \
            --rdp-tls-cert="${cfg.tlsCert}" \
            --rdp-tls-key="${cfg.tlsKey}" \
            --config="${westonIni}" \
            --socket=wayland-3 &
          WESTON_PID=$!

          for i in {1..50}; do
            if [ -S "$XDG_RUNTIME_DIR/wayland-3" ]; then
              break
            fi
            sleep 0.1
          done

          if ! kill -0 "$WESTON_PID" 2>/dev/null; then
            echo "Weston RDP server failed to start"
            exit 1
          fi

          export WAYLAND_DISPLAY=wayland-3

          exec ${pkgs.python3}/bin/python3 -c 'import signal, os, sys; signal.signal(signal.SIGCHLD, signal.SIG_DFL); os.execv(sys.argv[1], sys.argv[1:])' ${cfg.windowManager} --backend winit
        '';

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
