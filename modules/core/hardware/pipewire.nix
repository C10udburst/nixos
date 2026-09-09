{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.pipewire = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && true;
  };

  config = lib.mkIf cfg.pipewire {
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
