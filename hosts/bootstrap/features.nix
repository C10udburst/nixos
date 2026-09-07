{...}: {
  features = {
    core = {
      enable = true;
      hardware = {
        zram = false;
        fuse = false;
      };
    };

    services = {
      enable = true;
      tailscale.enable = false;
    };

    shell = {
      enable = true;
      scripts.enable = false;
    };

    gui = {
      enable = true;
      desktop = {
        driftwm.enable = false;
        plasma.enable = true;
      };
      apps = {
        brave.enable = true;
        editors = {
          vscode = false;
          office.libreoffice = false;
        };
        tools = {
          social.enable = false;
          llm.enable = false;
        };
      };
      dev = {
        enable = true;
        python.enable = true;
      };
    };

    compat.enable = false;
  };
}
