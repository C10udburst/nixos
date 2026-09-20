{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  networking.hostName = "bootstrap";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkDefault "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDr78YYF81SudwLa3sCOjGcdaB7o8bUUGjqq3j92IfwY+DUx1zI6pV9gMxLgXcQTaNVMSVYns433k6PbnDu3wbORyWz58fRjGJUozuwHUVXaQPV9Lrk5LurTdAkGL5Fn6gE5zTYgZL51E30ln6XzYhmZVaaQoCTlhQRIs93v8AEqz5RnnflB0j3huAz12sOC8iJ+LD976+bVZqMkflKL+y1j9y7yvjgMxYvTpsVVD7+GPjAW+tCzReRFhfaHWXCK4HHZ7V7LQ4SSd3sRiQzwesUtIU6rudVWP8SqWDdu+FjNdp6vXRupwtydBxvn7DVkIug7zhQztQlyc0CSKfeXWM9swciScCvDJCmt3MxrCpm1NgQG27gOPTslyjn9xq6W/4eaQUemcKR2BMCtGx2LjifxrROKXdwZm0AOne7H8w+uEfPAxlbZ9Wc9Oko4E8mMqk7dkREVtkNxwRO/CwqWyT5mLLXWQ45o93ZxmidZ4nGg2KsJAgdYGfbRrCE0hYNY78= cloudburst@cloudburst-laptop"
  ];

  users.users.cloudburst.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDr78YYF81SudwLa3sCOjGcdaB7o8bUUGjqq3j92IfwY+DUx1zI6pV9gMxLgXcQTaNVMSVYns433k6PbnDu3wbORyWz58fRjGJUozuwHUVXaQPV9Lrk5LurTdAkGL5Fn6gE5zTYgZL51E30ln6XzYhmZVaaQoCTlhQRIs93v8AEqz5RnnflB0j3huAz12sOC8iJ+LD976+bVZqMkflKL+y1j9y7yvjgMxYvTpsVVD7+GPjAW+tCzReRFhfaHWXCK4HHZ7V7LQ4SSd3sRiQzwesUtIU6rudVWP8SqWDdu+FjNdp6vXRupwtydBxvn7DVkIug7zhQztQlyc0CSKfeXWM9swciScCvDJCmt3MxrCpm1NgQG27gOPTslyjn9xq6W/4eaQUemcKR2BMCtGx2LjifxrROKXdwZm0AOne7H8w+uEfPAxlbZ9Wc9Oko4E8mMqk7dkREVtkNxwRO/CwqWyT5mLLXWQ45o93ZxmidZ4nGg2KsJAgdYGfbRrCE0hYNY78= cloudburst@cloudburst-laptop"
  ];

  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  environment.systemPackages = with pkgs; [
    tparted
    parted
    gptfdisk
    btrfs-progs
    e2fsprogs
    dosfstools
    xfsprogs
    util-linux
    nixos-install-tools
    git
    curl
    wget
    rsync
    jq
    efibootmgr
  ];

  system.stateVersion = "26.05";
}
