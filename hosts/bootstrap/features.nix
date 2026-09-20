_: {
  features = {
    core = {
      boot = {
        grub = true;
        grub32 = true;
      };
      hardware = {
        zram = false;
        fuse = false;
      };
      nix = {
        vulnix = false;
        ghcr = false;
      };
    };

    services = {
      openssh.enable = true;
      waypipe = true;
      tailscale.enable = false;
    };

    shell = {
      scripts.enable = false;
    };

    gui.enable = false;
    compat.enable = false;
    server.enable = false;
  };
}
