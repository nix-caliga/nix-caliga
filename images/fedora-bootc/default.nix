{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "fedora-bootc";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:5e0d17bc17db8b74380ff999172e044c1a8269e33ab1ef366b22f58ec3d69ac5";
      hash = "sha256-1Dn2N/xyf/Q6N6TWGszoLikQoR3IzUTngPVsEmkNms0=";
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
}
