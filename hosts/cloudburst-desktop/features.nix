_: {
  features = {
    core.hardware = {
      ddc = true;
    };

    services = {
      weylus = true;
      usbip = true;
    };

    gui = {
      desktop.driftwm.extracmds = [
        "wlr-randr --output HDMI-A-1 --pos 0,0 --output DP-1 --pos 1920,80"
      ];
      apps = {
        editors.jetbrains = true;
      };
      dev = {
        enable = true;
        arduino.enable = true;
        android = {
          dev = true;
          jadx = true;
        };
      };
    };

    compat = {
      wine = true;
      waydroid = true;
      podman.enable = true;
    };

    server.samba = {
      enable = true;
      paths = ["/mnt/dane"];
    };

    server.web = {
      enable = true;
      core.baseDomain = "desktop.wilkins.pl.eu.org";
      etcHosts.enable = true;
      pihole.enable = false;
      golink = false;
      homepage = false;
      homarr = true;
    };
  };
}
