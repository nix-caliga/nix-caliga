{ pkgs, ... }:
{
  layeredImage.fromImage = pkgs.dockerTools.pullImage {
    imageName = "quay.io/fedora/fedora-bootc";
    imageDigest = "sha256:b3f3896fdefc7e6b285a0df0667338e4438da8ad82cb8dbd9625ab34e8f35903";
    hash = "sha256-uME3d02FImrz3V/zLPdc73oo2LGSHm7WRbGTL17ianI=";
    finalImageName = "quay.io/fedora/fedora-bootc";
    finalImageTag = "44";
  };

  caliga.os = "fedora";
  caliga.core.enable = true;

  # TODO: remove later maybe. these are because im using distrobox for nix
  caliga.core.containerfile.enable = false;
  bootc.ostree-prepare-root.transientEtc = false;
  bootc.initramfs.regenerate.enable = false;

  users.users.root.hashedPassword = "";

  environment.systemPackages = [ pkgs.bats ];

  environment.etc."hostname".text = "hello-world";

  system.stateVersion = "25.11";
}
