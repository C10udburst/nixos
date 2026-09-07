{...}: {
  features = {
    core = {
      enable = true;
      hardware = {
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
        driftwm = {
          enable = true;
          extracmds = [
            "wlr-randr --output HDMI-A-1 --pos 0,0 --output DP-1 --pos 1920,80"
          ];
        };
        plasma.enable = true;
      };
      apps = {
        brave.enable = true;
        editors = {
          vscode = true;
          office = {
            libreoffice = true;
          };
          jetbrains.enable = true;
        };
        tools = {
          obs = true;
          social.enable = true;
          llm.enable = true;
        };
      };
      dev = {
        enable = true;
        programming = {
          enable = true;
          rust = true;
          go = true;
          node = true;
          kotlin = true;
        };
        python.enable = true;
        arduino = {
          enable = true;
          boards = [
            "arduino"
            "esp32"
            "digispark"
            "esp8266"
          ];
        };
        threed.enable = true;
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
      wine = true;
      waydroid = true;
      podman.enable = true;
    };

    server = {
      enable = true;
      samba = {
        enable = true;
        path = "/mnt/dane";
      };
    };
  };
}
