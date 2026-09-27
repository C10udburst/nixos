_: {
  features = {
    core.hardware = {
      mobile = true;
      nvidia = true;
    };

    services = {
      weylus = true;
      usbip = true;
    };

    gui = {
      apps.brave.apps = {
        social.discord = true;
        office = true;
      };
      games.enable = true;
      dev.enable = true;
    };

    compat.wine = true;
  };
}
