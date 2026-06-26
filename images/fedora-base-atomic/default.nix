{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "fedora-base-atomic";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora-ostree-desktops/base-atomic";
      imageDigest = "sha256:e2210ad379d8d914fd05bc4fb8e102147717142d1603a015bbf1322ad9e0c9fd";
      hash = "sha256-HOeTty3Q6JvRcTpZXbZ+yQizcIhjvDCoPpU/J/VTrW0=";
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
