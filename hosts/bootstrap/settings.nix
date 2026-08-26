{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "";
  mobile = false;
  touchscreen = false;
  slow = false;

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = false;
    extracmds = [];
  };
  jetbrains = false;
  vscode = false;
  llm = false;
  plasma = true;
  shell-undo = false;

  # NixOS-only modules
  android = {
    enable = false;
    dev = false;
  };
  appimage = false;
  brave = true;
  editors = false;
  fuse = false;
  greetd = {
    autologin = false;
  };
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
  threed = false;
  typst = false;
  utils = true;
  waydroid = false;
  waypipe = false;
  weston-rdp = false;
  zram = false;

  # Home-Manager-only modules
  git = true;
  social = false;
}
