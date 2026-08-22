{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "";
  mobile = true;
  touchscreen = false;
  slow = false;

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = true;
    extracmds = [];
  };
  jetbrains = false;
  vscode = true;
  llm = true;
  plasma = true;
  shell-undo = true;
  nushell = {
    enable = true;
    default = "term";
  };

  # NixOS-only modules
  android = {
    enable = true;
    dev = false;
  };
  gaming = true;
  appimage = true;
  brave = true;
  editors = false;
  nvidia = true;
  fuse = true;
  greetd = {
    autologin = false;
  };
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
  programming = {
    enable = true;
  };
  python = true;
  scripts = true;
  tailscale = true;
  peerix = true;
  threed = false;
  typst = false;
  utils = true;
  usbip = true;
  waydroid = false;
  waypipe = true;
  weston-rdp = false;
  zram = true;

  # Home-Manager-only modules
  git = true;
  social = true;
}
