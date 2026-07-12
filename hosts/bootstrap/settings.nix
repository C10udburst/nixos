{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "";

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = false;
    extracmds = [];
  };
  jetbrains = false;
  llm = false;
  plasma = true;

  # NixOS-only modules
  android = {
    enable = false;
    dev = false;
  };
  appimage = false;
  brave = true;
  editors = false;
  flatpak = false;
  fuse = false;
  greetd = true;
  java = false;
  kvm = false;
  latex = false;
  nettools = false;
  obs = false;
  office = false;
  openssh = true;
  packages = true;
  pipewire = true;
  podman = false;
  programming = false;
  python = true;
  scripts = false;
  tailscale = false;
  peerix = true;
  threed = false;
  typst = false;
  utils = true;
  waydroid = false;
  waypipe = false;
  weston-rdp = false;
  zram = false;

  # Home-Manager-only modules
  git = true;
  ulauncher = false;
  vencord = false;
}
