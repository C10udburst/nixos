{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.pipewire = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable && cfg.pipewire) {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
