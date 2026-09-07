{...}: {
  features = {
    core.hardware.ddc = true;

    services = {
      waypipe = true;
      weylus = true;
      usbip = true;
    };

    gui = {
      desktop = {
        driftwm.extracmds = [
          "wlr-randr --output HDMI-A-1 --pos 0,0 --output DP-1 --pos 1920,80"
        ];
      };
      apps = {
        threed.enable = true;
        editors = {
          vscode = true;
          office.libreoffice = true;
          jetbrains.enable = true;
          media.enable = true;
        };
        tools = {
          obs = true;
          social.enable = true;
          llm.enable = true;
          net.enable = true;
        };
      };
      dev = {
        enable = true;
        programming = {
          rust = true;
          go = true;
          node = true;
          kotlin = true;
        };
        python.enable = true;
        arduino.enable = true;
        documents = {
          latex = true;
          typst = true;
        };
        android = {
          enable = true;
          dev = true;
        };
      };
    };

    compat = {
      enable = true;
      appimage = true;
      wine = true;
      waydroid = true;
      podman.enable = true;
    };

    server.samba = {
      enable = true;
      paths = ["/mnt/dane"];
    };
  };
}
