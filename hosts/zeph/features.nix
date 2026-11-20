_: {
  features = {
    core = {
      hardware = {
        fuse = true;
        pipewire = false;
        nvidia = true;
        laptop-server = true;
        unattended = true;
      };
      java = false;
    };
    gui = {
      enable = false;
      dev.python.enable = true;
    };
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
    shell.utils.llm.pi.web = {
      enable = true;
      port = 30141;
      allowedHosts = ["pi.brix0.wilkins.pl.eu.org"];
    };
    compat.podman.enable = true;
  };
}
