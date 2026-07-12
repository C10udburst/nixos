{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.weston-rdp;

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
  options.systemSettings.weston-rdp = {
    enable = lib.mkEnableOption "Enable Weston RDP remote desktop daemon";

    user = lib.mkOption {
      type = lib.types.str;
      default = "cloudburst";
      description = "The user under whose session Weston and the window manager will run.";
    };

    tlsCert = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/weston-rdp/tls.crt";
      description = "Path to the RDP TLS certificate.";
    };

    tlsKey = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/weston-rdp/tls.key";
      description = "Path to the RDP TLS private key.";
    };

    gskRenderer = lib.mkOption {
      type = lib.types.str;
      default = "ngl";
      description = "GSK renderer environment variable value.";
    };

    windowManager = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.driftwm}/bin/driftwm";
      defaultText = lib.literalExpression "\${pkgs.driftwm}/bin/driftwm";
      description = "The window manager or session command to execute inside Weston.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Open the firewall port if enabled
    networking.firewall.allowedTCPPorts = [3389];

    # Enable lingering for the target user so their systemd user slice and runtime directories are created on boot
    users.users.${cfg.user}.linger = true;

    # Create the state directory on boot using tmpfiles
    systemd.tmpfiles.rules = [
      "d /var/lib/weston-rdp 0700 ${cfg.user} users - -"
    ];

    # Weston RDP Service
    systemd.services.weston-rdp = {
      description = "Weston RDP remote desktop service running ${cfg.windowManager}";
      after = ["network.target" "systemd-user-sessions.service"];
      wantedBy = ["multi-user.target"];
      enable = false;

      preStart = ''
        # Ensure directories exist
        mkdir -p "$(dirname "${cfg.tlsCert}")"
        mkdir -p "$(dirname "${cfg.tlsKey}")"

        # Generate self-signed TLS cert and key if they don't exist
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
          # Resolve user UID and export wayland session variables
          USER_UID=$(${pkgs.coreutils}/bin/id -u "${cfg.user}")
          export XDG_RUNTIME_DIR="/run/user/$USER_UID"
          export GSK_RENDERER="${cfg.gskRenderer}"

          # Ensure the runtime directory exists
          mkdir -p "$XDG_RUNTIME_DIR"
          chmod 700 "$XDG_RUNTIME_DIR"

          # Start Weston with RDP backend in the background
          ${pkgs.weston}/bin/weston \
            --backend=rdp \
            --address="0.0.0.0" \
            --port=3389 \
            --rdp-tls-cert="${cfg.tlsCert}" \
            --rdp-tls-key="${cfg.tlsKey}" \
            --config="${westonIni}" \
            --socket=wayland-3 &
          WESTON_PID=$!

          # Wait for Weston to create the wayland-3 socket
          for i in {1..50}; do
            if [ -S "$XDG_RUNTIME_DIR/wayland-3" ]; then
              break
            fi
            sleep 0.1
          done

          # Check if Weston is still running
          if ! kill -0 "$WESTON_PID" 2>/dev/null; then
            echo "Weston RDP server failed to start"
            exit 1
          fi

          # Run the window manager nested inside Weston
          export WAYLAND_DISPLAY=wayland-3
          exec ${cfg.windowManager}
        '';

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
