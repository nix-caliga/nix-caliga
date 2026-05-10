{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "ublue-bazzite";
    maxLayers = 130;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/ublue-os/bazzite";
      imageDigest = "sha256:d2f131cb9e5cd3c633bc19bf8bb82c156f47f70f6776cab6ae9a3c3bee2e4172";
      hash = "sha256-4sfr1H/FCImEX1fu6ZctxUe6JB6bz3wG1oHBNG9dYkA=";
      finalImageTag = "stable";
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
