_: {
  features = {
    core = {
      boot.timeout = 1;
      hardware = {
        fuse = true;
        pipewire = false;
        nvidia = true;
        laptop-server = true;
      };
      java = false;
    };
    gui.enable = false;
    server = {
    };
    services = {
      waypipe = true;
    };
    compat.podman.enable = true;
  };
}
