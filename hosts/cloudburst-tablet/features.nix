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

    shell = {
      git.enable = false;
      ranger = false;
      utils = {
        enable = false;
        core = true;
        diagnostics = true;
      };
      scripts = {
        dev = false;
        documents = false;
        media = false;
      };
    };

    gui = {
      greeter.autologin = "driftwm";
      desktop.plasma.enable = false;
      apps = {
        editors.enable = false;
        threed.enable = false;
        tools = {
          enable = false;
          konsole = true;
          organizeer = true;
          qalculate = true;
        };
        viewers.mayo = false;
      };
    };

    compat = {
      enable = false;
    };
  };
}
