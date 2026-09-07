{...}: {
  features = {
    core.hardware = {
      mobile = true;
      nvidia = true;
    };

    services = {
      waypipe = true;
      weylus = true;
      usbip = true;
    };

    gui = {
      apps = {
        threed.enable = true;
        editors = {
          vscode = true;
          office.libreoffice = true;
          media.enable = true;
        };
        tools = {
          social.enable = true;
          llm.enable = true;
          net.enable = true;
        };
      };
      games.enable = true;
      dev = {
        enable = true;
        programming.enable = true;
        python.enable = true;
        android.enable = true;
      };
    };

    compat = {
      enable = true;
      appimage = true;
      wine = true;
      podman.enable = true;
    };
  };
}
