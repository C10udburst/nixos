{...}: {
  features = {
    core = {
      enable = true;
      hardware = {
        mobile = true;
        nvidia = true;
        appimage = true;
      };
    };

    services = {
      enable = true;
      waypipe = true;
      weylus = true;
      usbip = true;
    };

    shell = {
      enable = true;
      scripts.enable = true;
    };

    gui = {
      enable = true;
      desktop = {
        driftwm.enable = true;
        plasma.enable = true;
      };
      apps = {
        brave.enable = true;
        editors = {
          vscode = true;
          office = {
            libreoffice = true;
          };
        };
        tools = {
          social.enable = true;
          llm.enable = true;
        };
      };
      dev = {
        enable = true;
        programming.enable = true;
        python.enable = true;
        threed.enable = true;
        android.enable = true;
      };
    };

    compat = {
      enable = true;
      wine = true;
      podman.enable = true;
    };
  };
}
