{
  username = "cloudburst";
  adminUsers = ["cloudburst"];

  sambaPath = "/mnt/dane";

  # Modules to enable across NixOS and Home Manager
  plasma = true;
  llm = true;
  jetbrains = true;
  driftwm = {
    enable = true;
    extracmds = [
      # sets monitor layout for my dual-monitor setup
      "wlr-randr --output HDMI-A-1 --pos 0,0 --output DP-1 --pos 1920,0"
    ];
  };

  # NixOS-only modules
  podman = true;
  android = true;
  waydroid = true;
  pipewire = true;
  openssh = true;
  packages = true;
  python = true;
  programming = true;
  java = true;
  utils = true;
  tailscale = true;
  xrdp = true;
  waypipe = true;
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
  greetd = true;

  # Home-Manager-only modules
  git = true;
  vencord = true;
  ulauncher = false;
}
