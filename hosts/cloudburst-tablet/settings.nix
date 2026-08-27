{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "";
  mobile = true;
  touchscreen = true;
  slow = true;

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = true;
    extracmds = [];
  };
  jetbrains = false;
  vscode = false;
  llm = false;
  plasma = false;
  shell-undo = false;
  wine = false;

  nushell = {
    enable = true;
    default = "term";
  };

  # NixOS-only modules
  android = {
    enable = false;
    dev = false;
  };
  appimage = false;
  brave = true;
  editors = false;
  fuse = true;
  greetd = {
    autologin = true;
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
  python = false;
  scripts = false;
  tailscale = true;
  threed = false;
  typst = false;
  utils = false;
  waydroid = false;
  waypipe = true;
  weston-rdp = false;
  zram = true;

  # Home-Manager-only modules
  git = true;
  social = false;
}
