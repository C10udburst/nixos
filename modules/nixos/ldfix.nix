{pkgs, ...}: {
  services.envfs.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib.out
    openssl
    libx11
    libxcursor
    libxrandr
    libxi
    libxext
    libxfixes
    libxtst
    libGL
    libxkbcommon
    dbus
    fontconfig
    freetype
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    nss
    nspr
    alsa-lib
    libuuid
    libdrm
    udev
  ];

  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /usr/bin"
    "L+ /sbin - - - - /bin"
  ];
}
