{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "/mnt/dane";
  mobile = false;

  # Modules to enable across NixOS and Home Manager
  driftwm = {
    enable = true;
    extracmds = [
      # sets monitor layout for my dual-monitor setup
      "wlr-randr --output HDMI-A-1 --pos 0,0 --output DP-1 --pos 1920,0"
    ];
  };
  jetbrains = true;
  llm = true;
  plasma = true;

  # NixOS-only modules
  android = {
    enable = true;
    dev = true;
  };
  appimage = true;
  brave = true;
  editors = true;
  flatpak = true;
  fuse = true;
  greetd = true;
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
    enable = false;
    boards = ["arduino" "esp32" "digispark" "esp8266"];
  };
  python = true;
  scripts = true;
  tailscale = true;
  peerix = true;
  threed = true;
  typst = true;
  utils = true;
  waydroid = true;
  waypipe = true;
  weston-rdp = false;
  zram = true;
  nvidia = false;

  # Home-Manager-only modules
  git = true;
  ulauncher = false;
  vencord = true;
}
