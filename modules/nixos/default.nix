{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./android.nix
    ./appimage.nix
    ./arduino.nix
    ./brave.nix
    ./driftwm.nix
    ./editors.nix
    ./flatpak.nix
    ./fonts.nix
    ./fuse.nix
    ./greetd.nix
    ./java.nix
    ./jetbrains.nix
    ./kvm.nix
    ./latex.nix
    ./ldfix.nix
    ./llm.nix
    ./locale.nix
    ./main.nix
    ./nettools.nix
    ./nix.nix
    ./nushell
    ./nvidia.nix
    ./obs.nix
    ./office.nix
    ./openssh.nix
    ./packages.nix
    ./peerix.nix
    ./pipewire.nix
    ./plasma.nix
    ./podman.nix
    ./programming.nix
    ./python.nix
    ./samba.nix
    ./scripts
    ./tailscale.nix
    ./theme.nix
    ./threed.nix
    ./typst.nix
    ./users.nix
    ./utils.nix
    ./waydroid.nix
    ./waypipe.nix
    ./weston-rdp.nix
    ./zram.nix
  ];

  options.hostSettings = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Loaded host settings from settings.nix";
  };

  config = {
    systemSettings = {
      users = lib.mkDefault (
        if config.hostSettings ? username
        then [config.hostSettings.username]
        else []
      );
      adminUsers = lib.mkDefault (config.hostSettings.adminUsers or []);

      android.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.android or false)
        then config.hostSettings.android.enable or false
        else config.hostSettings.android or false
      );
      android.dev = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.android or false)
        then config.hostSettings.android.dev or false
        else false
      );
      llm.enable = lib.mkDefault (config.hostSettings.llm or false);
      plasma.enable = lib.mkDefault (config.hostSettings.plasma or false);
      greetd.enable = lib.mkDefault (config.hostSettings.greetd or false);
      driftwm.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.driftwm or false)
        then config.hostSettings.driftwm.enable or false
        else config.hostSettings.driftwm or false
      );
      pipewire.enable = lib.mkDefault (config.hostSettings.pipewire or false);
      openssh.enable = lib.mkDefault (config.hostSettings.openssh or false);
      packages.enable = lib.mkDefault (config.hostSettings.packages or false);
      podman.enable = lib.mkDefault (config.hostSettings.podman or false);
      python.enable = lib.mkDefault (config.hostSettings.python or false);

      programming.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.enable or false
        else config.hostSettings.programming or false
      );
      programming.rust = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.rust or true
        else true
      );
      programming.go = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.go or true
        else true
      );
      programming.node = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.node or true
        else true
      );
      programming.kotlin = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.programming or false)
        then config.hostSettings.programming.kotlin or true
        else true
      );

      arduino.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.arduino or false)
        then config.hostSettings.arduino.enable or false
        else config.hostSettings.arduino or false
      );
      arduino.boards = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.arduino or false)
        then config.hostSettings.arduino.boards or ["arduino"]
        else ["arduino"]
      );

      java.enable = lib.mkDefault (config.hostSettings.java or false);
      jetbrains.enable = lib.mkDefault (config.hostSettings.jetbrains or false);
      utils.enable = lib.mkDefault (config.hostSettings.utils or false);
      tailscale.enable = lib.mkDefault (config.hostSettings.tailscale or false);
      peerix.enable = lib.mkDefault (config.hostSettings.peerix or false);
      weston-rdp.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.weston-rdp or false)
        then config.hostSettings.weston-rdp.enable or false
        else config.hostSettings.weston-rdp or false
      );
      weston-rdp.user = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.weston-rdp or false)
        then config.hostSettings.weston-rdp.user or config.hostSettings.username or "cloudburst"
        else config.hostSettings.username or "cloudburst"
      );
      weston-rdp.windowManager = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.weston-rdp or false)
        then config.hostSettings.weston-rdp.windowManager or "${pkgs.driftwm}/bin/driftwm"
        else "${pkgs.driftwm}/bin/driftwm"
      );

      editors.enable = lib.mkDefault (config.hostSettings.editors or false);
      threed.enable = lib.mkDefault (config.hostSettings.threed or false);
      fuse.enable = lib.mkDefault (config.hostSettings.fuse or false);
      office.enable = lib.mkDefault (config.hostSettings.office or false);
      latex.enable = lib.mkDefault (config.hostSettings.latex or false);
      typst.enable = lib.mkDefault (config.hostSettings.typst or false);
      appimage.enable = lib.mkDefault (config.hostSettings.appimage or false);
      nettools.enable = lib.mkDefault (config.hostSettings.nettools or false);
      obs.enable = lib.mkDefault (config.hostSettings.obs or false);
      zram.enable = lib.mkDefault (config.hostSettings.zram or false);
      kvm.enable = lib.mkDefault (config.hostSettings.kvm or false);
      brave.enable = lib.mkDefault (config.hostSettings.brave or false);
      flatpak.enable = lib.mkDefault (config.hostSettings.flatpak or false);
      scripts.enable = lib.mkDefault (config.hostSettings.scripts or false);
      waydroid.enable = lib.mkDefault (config.hostSettings.waydroid or false);

      waypipe.enable = lib.mkDefault (config.hostSettings.waypipe or false);

      nvidia.enable = lib.mkDefault (config.hostSettings.nvidia or false);

      samba.enable = lib.mkDefault (config.hostSettings.sambaPath or "" != "");
      samba.path = lib.mkDefault (config.hostSettings.sambaPath or "");

      nushell.enable = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.nushell or false)
        then config.hostSettings.nushell.enable or false
        else config.hostSettings.nushell or false
      );
      nushell.default = lib.mkDefault (
        if builtins.isAttrs (config.hostSettings.nushell or false)
        then config.hostSettings.nushell.default or "none"
        else "none"
      );
    };
  };
}
