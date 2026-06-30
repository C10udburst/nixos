{
  config,
  lib,
  ...
}: let
  cfg = config.systemSettings.pipewire;
in {
  options.systemSettings.pipewire = {
    enable = lib.mkEnableOption "Enable sound with PipeWire";
  };

  config = lib.mkIf cfg.enable {
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
