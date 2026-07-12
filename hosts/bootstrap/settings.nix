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
  plasma = false;

  # NixOS-only modules
  android = {
    enable = false;
    dev = false;
  };
  appimage = false;
  brave = false;
  editors = false;
  flatpak = false;
  fuse = false;
  greetd = false;
  java = false;
  kvm = false;
  latex = false;
  nettools = false;
  obs = false;
  office = false;
  openssh = false;
  packages = false;
  pipewire = false;
  podman = false;
  programming = false;
  python = false;
  scripts = false;
  tailscale = false;
  peerix = true;
  threed = false;
  typst = false;
  utils = false;
  waydroid = false;
  waypipe = false;
  weston-rdp = false;
  zram = false;

  # Home-Manager-only modules
  git = false;
  ulauncher = false;
  vencord = false;
}
