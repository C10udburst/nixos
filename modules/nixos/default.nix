{
  config,
  lib,
  ...
}: {
  imports = [
    ./android.nix
    ./llm.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./packages.nix
    ./pipewire.nix
    ./plasma.nix
    ./driftwm.nix
    ./podman.nix
    ./users.nix
    ./python.nix
    ./programming.nix
    ./ldfix.nix
    ./java.nix
    ./jetbrains.nix
    ./utils.nix
    ./tailscale.nix
    ./xrdp.nix
    ./fonts.nix
    ./editors.nix
    ./threed.nix
    ./fuse.nix
    ./office.nix
    ./latex.nix
    ./appimage.nix
    ./nettools.nix
    ./obs.nix
    ./zram.nix
    ./kvm.nix
  ];

  options.hostSettings = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Loaded host settings from settings.nix";
  };

  config.systemSettings = {
    users = lib.mkDefault (
      if config.hostSettings ? username
      then [config.hostSettings.username]
      else []
    );
    adminUsers = lib.mkDefault (config.hostSettings.adminUsers or []);

    android.enable = lib.mkDefault (config.hostSettings.android or false);
    llm.enable = lib.mkDefault (config.hostSettings.llm or false);
    plasma.enable = lib.mkDefault (config.hostSettings.plasma or false);
    driftwm.enable = lib.mkDefault (config.hostSettings.driftwm or false);
    pipewire.enable = lib.mkDefault (config.hostSettings.pipewire or false);
    openssh.enable = lib.mkDefault (config.hostSettings.openssh or false);
    packages.enable = lib.mkDefault (config.hostSettings.packages or false);
    podman.enable = lib.mkDefault (config.hostSettings.podman or false);
    python.enable = lib.mkDefault (config.hostSettings.python or false);
    programming.enable = lib.mkDefault (config.hostSettings.programming or false);
    java.enable = lib.mkDefault (config.hostSettings.java or false);
    jetbrains.enable = lib.mkDefault (config.hostSettings.jetbrains or false);
    utils.enable = lib.mkDefault (config.hostSettings.utils or false);
    tailscale.enable = lib.mkDefault (config.hostSettings.tailscale or false);
    xrdp.enable = lib.mkDefault (config.hostSettings.xrdp or false);
    editors.enable = lib.mkDefault (config.hostSettings.editors or false);
    threed.enable = lib.mkDefault (config.hostSettings.threed or false);
    fuse.enable = lib.mkDefault (config.hostSettings.fuse or false);
    office.enable = lib.mkDefault (config.hostSettings.office or false);
    latex.enable = lib.mkDefault (config.hostSettings.latex or false);
    appimage.enable = lib.mkDefault (config.hostSettings.appimage or false);
    nettools.enable = lib.mkDefault (config.hostSettings.nettools or false);
    obs.enable = lib.mkDefault (config.hostSettings.obs or false);
    zram.enable = lib.mkDefault (config.hostSettings.zram or false);
    kvm.enable = lib.mkDefault (config.hostSettings.kvm or false);
  };
}
