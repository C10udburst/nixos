{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  # Modules to enable across NixOS and Home Manager
  plasma = true;
  llm = true;

  # NixOS-only modules
  podman = true;
  android = true;
  pipewire = true;
  openssh = true;
  packages = true;
  python = true;
  programming = true;
  java = true;
  utils = true;
  tailscale = true;
  xrdp = true;
  editors = true;
  threed = true;
  fuse = true;
  office = true;
  latex = true;
  appimage = true;
  nettools = true;
  obs = true;

  # Home-Manager-only modules
  git = true;
}
