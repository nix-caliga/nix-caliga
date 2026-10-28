{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "fedora-bootc";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:a329903517f5dbd709721cba0cb1b6d0cc05f01b9e5feb59c2b6bbe9eb083ade";
      hash = "sha256-C01WDuFVrskA+LFoHeBRLMto7AcY88af/qUGXHzz1XA=";
      finalImageName = "quay.io/fedora/fedora-bootc";
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
