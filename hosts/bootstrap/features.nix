{...}: {
  features = {
    core.hardware = {
      zram = false;
      fuse = false;
    };

    services.tailscale.enable = false;

    shell.scripts.enable = false;

    gui = {
      desktop.driftwm.enable = false;
      dev.python.enable = true;
    };

    compat.enable = false;
  };
}
