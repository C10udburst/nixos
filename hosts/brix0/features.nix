_: {
  features = {
    core = {
      hardware = {
        fuse = false;
        pipewire = false;
        unattended = true;
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
