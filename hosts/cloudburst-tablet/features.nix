_: {
  features = {
    core = {
      boot = {
        systemd = false;
        grub32 = true;
      };
      hardware = {
        mobile = true;
        touchscreen = true;
        slow = true;
        bluetooth = false;
      };
    };

    services = {
      waypipe = true;
    };

    shell = {
      git.enable = false;
      ranger.enable = false;
      utils = {
        enable = false;
        core = true;
      };
      scripts = {
        dev = false;
        documents = false;
      };
    };

    gui = {
      greeter.autologin = "driftwm";
      desktop.plasma.enable = false;
      apps = {
        editors.enable = false;
        tools = {
          enable = false;
          konsole = true;
          organizeer = true;
          calc = true;
        };
        viewers.mayo = false;
      };
      dev.enable = false;
    };

    compat.enable = false;
  };
}
