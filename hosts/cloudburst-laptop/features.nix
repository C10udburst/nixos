_: {
  features = {
    core.hardware = {
      mobile = true;
      nvidia = true;
    };

    services = {
      weylus = true;
      usbip = true;
      vpn.openvpn = true;
    };

    gui = {
      apps.brave.apps = {
        office = true;
        other.vscode = true;
      };
      games.enable = true;
      dev.enable = true;
    };

    compat = {
      wine = true;
      podman.enable = true;
      appimage = true;
    };
  };
}
