_: {
  features = {
    core = {
      boot.timeout = 1;
      hardware = {
        fuse = true;
        pipewire = false;
        nvidia = true;
      };
      java = false;
    };
    gui.enable = false;
    server = {
    };
    services = {
      waypipe = false;
    };
    compat.podman.enable = true;
  };
}
