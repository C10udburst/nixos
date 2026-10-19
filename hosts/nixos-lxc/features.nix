_: {
  features = {
    core = {
      hardware = {
        enable = false;
        slow = true;
      };
      boot.enable = false;
      java = false;
      # nixos-lxc has no recipient key in secrets.nix, so no agenix secrets here
      secrets.enable = false;
      nix = {
        vulnix = false;
        ghcr = false;
      };
    };
    gui.enable = false;
    shell = {
      git.enable = false;
      ranger = false;
      nushell.scripts = false;
      utils = {
        enable = false;
        core = true;
      };
      scripts.enable = false;
    };
    services = {
      tailscale = {
        exitNode = true;
        udpGro = false;
      };
      forward.map = [
        {
          from = "192.168.1.65:443";
          to = "100.80.36.58:443";
        }
        {
          from = "192.168.1.65:80";
          to = "100.80.36.58:80";
        }
      ];
      waypipe = false;
    };
    compat.enable = false;
  };
}
