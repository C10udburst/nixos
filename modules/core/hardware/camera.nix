{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware.camera;
in {
  options.features.core.hardware.camera = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.core.hardware.enable && false;
    };

    gstreamer = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire.enable = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      libcamera
      v4l-utils
    ];

    services.pipewire.wireplumber.extraConfig.ipu3-camera = {
      "monitor.v4l2.rules" = [
        {
          matches = [{"device.product.name" = "ipu3-imgu";}];
          actions = {
            "update-props" = {
              "device.disabled" = true;
            };
          };
        }
        {
          matches = [{"device.product.name" = "Intel IPU3 CIO2";}];
          actions = {
            "update-props" = {
              "device.disabled" = true;
            };
          };
        }
      ];
    };

    environment.sessionVariables = lib.mkIf cfg.gstreamer {
      GST_PLUGIN_PATH = ["${pkgs.libcamera}/lib/gstreamer-1.0"];
    };
  };
}
