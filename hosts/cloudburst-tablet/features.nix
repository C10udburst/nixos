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
        eco = true;
        ssd.smartd = false;
      };
      nix = {
        vulnix = false;
        ghcr = false;
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
      #greeter.autologin = "driftwm";
      greeter.sddm.rotate = "270";
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
