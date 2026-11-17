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
      web = {
        enable = true;
      };
    };
    services = {
      flaresolverr.enable = true;
      rclone.enable = false;
      tailscale = {
        exitNode = true;
        interface = "enp0s31f6";
      };
      waypipe = false;
    };
    shell.utils.llm.enable = false;
    compat.podman.enable = true;
  };
}
