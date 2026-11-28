{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.services.voxtype;
  avxEnabled = config.features.core.hardware.avx;

  tomlFormat = pkgs.formats.toml {};

  # nixpkgs pins RUSTFLAGS = "-C target-cpu=x86-64-v3", so the stock binary is
  # AVX2-only and SIGILLs on the surface CPU. The bundled whisper.cpp/ggml part
  voxtypeSafe = pkgs.voxtype.overrideAttrs (_finalAttrs: previousAttrs: {
    env =
      (previousAttrs.env or {})
      // {
        RUSTFLAGS = "-C target-cpu=x86-64-v2";
      };
  });

  voxtypePackage =
    if avxEnabled
    then pkgs.voxtype
    else voxtypeSafe;

  configToml = tomlFormat.generate "voxtype-config.toml" (
    lib.recursiveUpdate
    (builtins.fromTOML (builtins.readFile "${voxtypePackage}/share/voxtype/default-config.toml"))
    {
      whisper = {
        mode = "remote";
        remote_endpoint = cfg.endpoint;
        remote_model = cfg.model;
        model = cfg.model;
        language = cfg.language;
      };

      # driftwm owns the chord (mod+shift+return -> voxtype record toggle)
      hotkey.enabled = false;
      # the noctalia voxtype plugin draws the dictation overlay instead
      osd.enabled = false;
    }
  );
in {
  options.features.gui.services.voxtype = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.services.enable && true;
    };
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://evo-x2.brix0.wilkins.pl.eu.org";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "whisper-v3:turbo";
    };
    language = lib.mkOption {
      type = lib.types.str;
      default = "auto";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [voxtypePackage];

    home-manager.users.cloudburst = {
      # force = true because `voxtype configure` writes this very file
      xdg.configFile."voxtype/config.toml" = {
        source = configToml;
        force = true;
      };

      systemd.user.services.voxtype = {
        Unit = {
          Description = "Voxtype push-to-talk voice-to-text daemon";
          PartOf = ["graphical-session.target"];
          After = [
            "graphical-session.target"
            "pipewire.service"
            "pipewire-pulse.service"
          ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${voxtypePackage}/bin/voxtype daemon";
          Restart = "on-failure";
          RestartSec = "5";
        };

        Install.WantedBy = ["graphical-session.target"];
      };
    };
  };
}
