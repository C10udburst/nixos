_: {
  features = {
    core = {
      boot.timeout = 1;
      hardware = {
        fuse = true;
        pipewire = false;
        nvidia = true;
        laptop-server = true;
      };
      java = false;
    };
    gui.enable = false;
    server = {
      llm.ollama = {
        enable = true;
        models = [
          "gemma3:1b"
          "qwen3.5:2b"
          "fixt/home-3b-v3:q4_k_m"
        ];
      };
    };
    services = {
      waypipe = true;
      tailscale.enable = false;
    };
    compat.podman.enable = true;
  };
}
