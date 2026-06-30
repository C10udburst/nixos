{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.podman;

  qocker = let
    pythonEnv = pkgs.python3.withPackages (ps: [
      ps.pyqt5
    ]);
  in
    pkgs.stdenv.mkDerivation rec {
      pname = "qocker";
      version = "1.0.0";

      src = pkgs.fetchFromGitHub {
        owner = "xlmnxp";
        repo = "qocker";
        rev = "6fbf90cfbe4ef1f3197b7b46b19a2b58ee3d4f57";
        hash = "sha256-M0U4mfCovwrVN+D7T11cwafz9PTBojLU8QfBMWCU+80=";
      };

      nativeBuildInputs = [
        pkgs.qt5.wrapQtAppsHook
        pkgs.makeWrapper
      ];

      buildInputs = [
        pkgs.qt5.qtbase
        pkgs.qt5.qtwayland
      ];

      installPhase = ''
        mkdir -p $out/bin $out/share/qocker
        cp -r * $out/share/qocker/

        # Create wrapper script that launches Python with PyQt5 and Qt environment
        makeWrapper ${pythonEnv}/bin/python3 $out/bin/qocker \
          --add-flags "$out/share/qocker/main.py" \
          --prefix QT_PLUGIN_PATH : "${pkgs.qt5.qtbase.bin}/${pkgs.qt5.qtbase.qtPluginPrefix}" \
          --prefix QT_PLUGIN_PATH : "${pkgs.qt5.qtwayland.bin}/${pkgs.qt5.qtbase.qtPluginPrefix}"
      '';
    };
in {
  options.systemSettings.podman = {
    enable = lib.mkEnableOption "Enable Podman container virtualisation";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    environment.systemPackages = [
      pkgs.docker-compose
      qocker
    ];

    systemd.tmpfiles.rules = [
      "L+ /var/run/docker.sock - - - - /run/podman/podman.sock"
    ];
  };
}
