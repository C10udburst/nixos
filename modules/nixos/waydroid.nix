{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.waydroid;
  auroraStoreApk = pkgs.fetchurl {
    url = "https://f-droid.org/repo/com.aurora.store_45.apk";
    sha256 = "0ajiq91sn2v2f3zfij57cq65g962yfa1i7iqhjb13fk9j01a4v1r";
  };
in {
  options.systemSettings.waydroid = {
    enable = lib.mkEnableOption "Enable declarative Waydroid with GApps and Aurora Store";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.waydroid.enable = true;
    virtualisation.waydroid.package = pkgs.waydroid-nftables;

    systemd.services.waydroid-init = {
      description = "Declarative Waydroid Initialization";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      before = ["waydroid-container.service"];
      path = [config.virtualisation.waydroid.package pkgs.curl pkgs.util-linux];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Initialize Waydroid if waydroid.cfg doesn't exist
        if [ ! -f /var/lib/waydroid/waydroid.cfg ]; then
          echo "Initializing Waydroid with GAPPS..."
          mkdir -p /var/lib/waydroid
          waydroid init -s GAPPS -f
        fi
      '';
    };

    systemd.services.waydroid-config = {
      description = "Declarative Waydroid Configuration";
      wantedBy = ["multi-user.target"];
      after = ["waydroid-container.service"];
      bindsTo = ["waydroid-container.service"];
      path = [config.virtualisation.waydroid.package pkgs.util-linux pkgs.coreutils pkgs.gnugrep];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        echo "Waiting for Waydroid boot..."
        # Wait for Waydroid to boot
        for i in {1..30}; do
          if waydroid shell getprop sys.boot_completed 2>/dev/null | grep -q 1; then
            echo "Waydroid boot completed!"
            break
          fi
          sleep 2
        done

        echo "Applying Stylix base0D color: ${config.lib.stylix.colors.base0D}"
        waydroid shell settings put secure theme_customization_overlay_packages \
          '{"android.theme.customization.theme_style":"TONAL_SPOT","android.theme.customization.color_source":"preset","android.theme.customization.system_palette":"#${config.lib.stylix.colors.base0D}"}'
        echo 'Applying extra settings for Waydroid...'
        waydroid shell settings put global development_settings_enabled 1
        waydroid shell settings put global package_verifier_enable 0
        waydroid shell settings put secure assistant 0

        echo "Configuring Waydroid properties..."
        waydroid prop set persist.waydroid.multi_windows true


        # Deploy Aurora Store APK declaratively
        echo "Deploying Aurora Store APK..."
        mkdir -p /var/lib/waydroid/overlay/system/app/AuroraStore
        cp -f ${auroraStoreApk} /var/lib/waydroid/overlay/system/app/AuroraStore/AuroraStore.apk
        chmod 644 /var/lib/waydroid/overlay/system/app/AuroraStore/AuroraStore.apk
        chown -R root:root /var/lib/waydroid/overlay/system/app/AuroraStore
      '';
    };
  };
}
