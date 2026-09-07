{...}: {
  features = {
    core = {
      enable = true;
      boot = {
        systemd = false;
        grub32 = true;
      };
      hardware = {
        mobile = true;
        touchscreen = true;
        slow = true;
        bluetooth = true;
      };
    };

    services = {
      enable = true;
      waypipe = true;
    };

    shell = {
      enable = true;
      scripts = {
        enable = false;
        hardware = true;
      };
      utils.enable = false;
    };

    gui = {
      enable = true;
      greeter = {
        autologin = "driftwm";
      };
      desktop = {
        driftwm.enable = true;
        plasma.enable = false;
      };
      apps = {
        brave.enable = true;
        editors = {
          enable = false;
        };
        tools = {
          enable = false;
          nomacs = true;
          haruna = true;
          konsole = true;
          okular = true;
          dolphin = true;
        };
      };
      dev.enable = false;
    };

    compat.enable = false;
  };
}
