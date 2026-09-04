{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "/mnt/dane";
  mobile = false;
  touchscreen = false;
  slow = false;

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = true;
    extracmds = [
      # sets monitor layout for my dual-monitor setup
      "wlr-randr --output HDMI-A-1 --pos 0,0 --output DP-1 --pos 1920,80"
    ];
  };
  jetbrains = true;
  vscode = true;
  llm = true;
  plasma = true;
  shell-undo = false;
  wine = true;
  nushell = {
    enable = true;
    default = "term";
  };

  # NixOS-only modules
  android = {
    enable = true;
    dev = true;
  };
  appimage = true;
  brave = true;
  editors = true;
  fuse = true;
  greetd = {
    autologin = false;
  };
  java = true;
  kvm = true;
  latex = true;
  nettools = true;
  obs = true;
  office = true;
  openssh = true;
  packages = true;
  pipewire = true;
  podman = true;
  programming = {
    enable = true;
    rust = true;
    go = true;
    node = true;
    kotlin = true;
  };
  arduino = {
    enable = true;
    boards = [
      "arduino"
      "esp32"
      "digispark"
      "esp8266"
    ];
  };
  python = true;
  scripts = true;
  tailscale = true;
  threed = true;
  typst = true;
  utils = true;
  usbip = true;
  waydroid = true;
  waypipe = true;
  weylus = true;
  weston-rdp = false;
  zram = true;
  nvidia = false;

  # Home-Manager-only modules
  git = true;
  social = true;
}
