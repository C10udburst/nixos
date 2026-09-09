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
      games.enable = true;
      dev.enable = true;
    };

    compat.wine = true;
  };
}
