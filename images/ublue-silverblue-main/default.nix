{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "ublue-silverblue-main";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/ublue-os/silverblue-main";
      imageDigest = "sha256:d1ed0889b46527af941d3be64ad76acda1c8679369b6ffd46df19be3320ed85b";
      hash = "sha256-X7QRVx3wMs3x3HoifUM1PrCS5fK4K+NUrJMNTiff9Ak=";
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
