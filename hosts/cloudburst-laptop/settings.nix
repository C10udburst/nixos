{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "";
  mobile = true;

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = true;
    extracmds = [];
  };
  jetbrains = false;
  llm = true;
  plasma = true;

  # NixOS-only modules
  android = {
    enable = true;
    dev = false;
  };
  appimage = true;
  brave = true;
  editors = false;
  nvidia = true;
  flatpak = true;
  fuse = true;
  greetd = true;
  java = true;
  kvm = false;
  latex = false;
  nettools = true;
  obs = false;
  office = true;
  openssh = true;
  packages = true;
  pipewire = true;
  podman = false;
  programming = false;
  python = true;
  scripts = true;
  tailscale = true;
  peerix = true;
  threed = false;
  typst = false;
  utils = true;
  waydroid = false;
  waypipe = true;
  weston-rdp = false;
  zram = true;

  # Home-Manager-only modules
  git = true;
  ulauncher = false;
  vencord = true;
}
