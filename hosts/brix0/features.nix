_: {
  features = {
    core = {
      boot.timeout = 1;
      hardware = {
        fuse = false;
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
    services = {
      rclone.enable = true;
      tailscale.exitNode = true;
      waypipe = false;
    };
    compat.podman.enable = true;
  };
}
