{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.westonRdp;
  user = "cloudburst";
  tlsCert = "/var/lib/weston-rdp/tls.crt";
  tlsKey = "/var/lib/weston-rdp/tls.key";
  gskRenderer = "ngl";

  desktopCmd =
    if cfg.desktop == "plasma"
    then "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland"
    else "${pkgs.python3}/bin/python3 -c 'import signal, os, sys; signal.signal(signal.SIGCHLD, signal.SIG_DFL); os.execv(sys.argv[1], sys.argv[1:])' ${pkgs.driftwm}/bin/driftwm --backend winit";

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
      default = config.features.server.enable && false;
    };

    desktop = lib.mkOption {
      type = lib.types.enum [
        "plasma"
        "driftwm"
      ];
      default =
        if (config.features.gui.desktop.driftwm.enable or false)
        then "driftwm"
        else if (config.features.gui.desktop.plasma.enable or false)
        then "plasma"
        else "driftwm";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [3389];

    users.users.${user}.linger = true;

    systemd.tmpfiles.rules = [
      "d /var/lib/weston-rdp 0700 ${user} users - -"
    ];

    systemd.services.weston-rdp = {
      description = "Weston RDP remote desktop service running ${cfg.desktop}";
      after = [
        "network.target"
        "systemd-user-sessions.service"
      ];
      wantedBy = ["multi-user.target"];

      preStart = ''
        mkdir -p "$(dirname "${tlsCert}")"
        mkdir -p "$(dirname "${tlsKey}")"

        if [ ! -f "${tlsCert}" ] || [ ! -f "${tlsKey}" ]; then
          echo "Generating self-signed RDP TLS certificate and key..."
          ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${tlsKey}" \
            -out "${tlsCert}" \
            -subj "/C=${countryCode}/CN=Weston RDP Server"

          chmod 600 "${tlsKey}"
          chmod 644 "${tlsCert}"
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = user;
        WorkingDirectory = "/home/${user}";

        ExecStart = pkgs.writeShellScript "start-weston-rdp" ''
          USER_UID=$(${pkgs.coreutils}/bin/id -u "${user}")
          export HOME="/home/${user}"
          export XDG_RUNTIME_DIR="/run/user/$USER_UID"
          export GSK_RENDERER="${gskRenderer}"
          export PATH="/run/wrappers/bin:/home/${user}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:${lib.makeBinPath [pkgs.weston]}"

          mkdir -p "$XDG_RUNTIME_DIR"
          chmod 700 "$XDG_RUNTIME_DIR"

          ${pkgs.weston}/bin/weston \
            --backend=rdp \
            --address="0.0.0.0" \
            --port=3389 \
            --rdp-tls-cert="${tlsCert}" \
            --rdp-tls-key="${tlsKey}" \
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

          exec ${desktopCmd}
        '';

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
