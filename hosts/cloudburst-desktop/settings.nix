{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "/mnt/dane";

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
  jetbrains = true;
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
  zram = true;
  kvm = true;
  brave = true;
  flatpak = true;
  scripts = true;

  # Home-Manager-only modules
  git = true;
  driftwm = true;
  ulauncher = false;
}
