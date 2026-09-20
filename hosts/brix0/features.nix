_: {
  features = {
    core = {
      boot.timeout = 1;
      hardware = {
        pipewire = false;
      };
      java = false;
    };
    gui.enable = false;
    server = {
      enable = true;
      samba = {
        enable = true;
        paths = ["/opt/dane"];
      };
      web.enable = true;
    };
  };
}
