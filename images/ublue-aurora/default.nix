{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "ublue-aurora";
    maxLayers = 130;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/ublue-os/aurora";
      imageDigest = "sha256:3325ab9b573122b7c24d5bf898fbe0f87f871f2f96cfe8c747d562853c939562";
      hash = "sha256-lTxeybwI0l8AACH/hh6UWi/g7ZTYGZN08u/gjuxHOIs=";
      finalImageTag = "44";
    };
  };

  caliga.os = "fedora";
  caliga.core.enable = true;

  users.users.test = {
    isNormalUser = true;
    uid = 1001;
    description = "Test User";
    initialPassword = "test";
  };

  users.users.root.hashedPassword = "";

  services.bootc-update = {
    enable = true;
    schedule = {
      onBootSec = "20s";
      onUnitActiveSec = "20s";
    };
  };

  environment.systemPackages = [ pkgs.cowsay ];

  system.stateVersion = "25.11";

  nix.enable = true;

  bootc.ostree-prepare-root.transientEtc = true;
  caliga.core.containerfile.enable = true;
}
