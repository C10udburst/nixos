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
      apps.brave.apps.office = true;
      games.enable = true;
      dev.enable = true;
    };

    compat.wine = true;
  };
}
