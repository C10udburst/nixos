{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  hostSettings = import ./settings.nix;

  isw = pkgs.stdenv.mkDerivation {
    pname = "isw";
    version = "latest";

    src = inputs.isw;

    nativeBuildInputs = [pkgs.makeWrapper];
    buildInputs = [pkgs.python3];

    installPhase = ''
      runHook preInstall
      install -Dm755 isw $out/bin/isw
      patchShebangs $out/bin/isw
      wrapProgram $out/bin/isw \
        --prefix PATH : ${lib.makeBinPath [pkgs.coreutils]}
      install -Dm644 etc/isw.conf $out/etc/isw.conf
      install -Dm644 usr/lib/systemd/system/isw@.service $out/lib/systemd/system/isw@.service
      runHook postInstall
    '';

    postFixup = ''
      substituteInPlace $out/lib/systemd/system/isw@.service \
        --replace "/usr/bin/isw" "$out/bin/isw" \
        --replace "/usr/bin/sleep" "${pkgs.coreutils}/bin/sleep"
    '';
  };
in {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    inputs.nixos-hardware.nixosModules.msi-gl65-10SDR-492
    ../../modules/nixos
  ];

  hostSettings = hostSettings;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  # Load ec_sys kernel module with write support for MSI fan control (isw)
  boot.kernelModules = ["ec_sys"];
  boot.kernelParams = ["ec_sys.write_support=1"];

  networking.hostName = "cloudburst-laptop";
  networking.firewall.enable = false;

  environment.systemPackages = [
    isw
  ];

  environment.etc."isw.conf".source = "${isw}/etc/isw.conf";

  systemd.packages = [isw];

  home-manager = {
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${hostSettings.username}" = import ./home.nix;
    };
  };

  system.stateVersion = "26.05";
}
