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
    };
    gui = {
      enable = false;
      dev = {
        android = {
          enable = true;
          scrcpy = false;
          dev = true;
        };
        python.enable = true;
      };
      apps.editors.vscode.web.enable = true;
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
      # Fronted by brix0 as pi-dash.brix0.wilkins.pl.eu.org.
      dash.enable = true;
    };
    compat.podman.enable = true;
  };
}
