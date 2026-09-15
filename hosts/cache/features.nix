_: {
  features = {
    core = {
      boot = {
        systemd = false;
        grub32 = true;
      };
      hardware = {
        ddc = true;
        touchscreen = true;
      };
    };

    services = {
      weylus = true;
      usbip = true;
    };

    gui = {
      apps = {
        brave.apps = {
          office = true;
          social.web = true;
        };
        threed.freecad = false;
        threed.blender = false;
      };
      dev = {
        enable = true;
        documents.enable = false;
        arduino.enable = true;
        android = {
          dev = true;
          jadx = true;
        };
        programming = {
          go = false;
          kotlin = false;
          rust = false;
          node = false;
        };
      };
    };

    compat = {
      wine = true;
      waydroid = true;
      podman.enable = true;
    };
  };
}
