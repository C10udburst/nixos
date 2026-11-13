{
  config,
  lib,
  ...
}: {
  options.features.core.hardware = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
    mobile = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    slow = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    # Baseline of the CPU instruction set: false means no AVX/AVX2, so
    # runtime-bundled binaries (bun) and SIMD-heavy builds (whisper.cpp/ggml)
    # have to be rebuilt for the SSE4.2 baseline.
    avx = lib.mkOption {
      type = lib.types.bool;
      default = !config.features.core.hardware.slow;
    };
  };
}
