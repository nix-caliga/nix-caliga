{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "fedora-silverblue";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora-ostree-desktops/silverblue";
      imageDigest = "sha256:5b5f80515ba17fb604a40cefcc636bca5b037a3bb21253dd92ae13fc6c8d61ae";
      hash = "sha256-/HBNEcPaUUq/05DT6/1bht8tvtWUZrEVekLTuwqwW8E=";
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
