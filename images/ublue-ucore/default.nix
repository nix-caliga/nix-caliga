{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "ublue-ucore";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/ublue-os/ucore";
      imageDigest = "sha256:7e4878e3286b140850b7072afeeeaeb8b8c82cac30d4efd15aca4fabb6373832";
      hash = "sha256-jEbaMU1pJsW12XsxqrCHlVha1zrjBeI1vynYiMjyQiE=";
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
