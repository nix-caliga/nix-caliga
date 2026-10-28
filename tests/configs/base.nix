{ pkgs, ... }:
{
  layeredImage.fromImage = pkgs.dockerTools.pullImage {
    imageName = "quay.io/fedora/fedora-bootc";
    imageDigest = "sha256:ac84835b92a08027b1f7579cc85483bd886ccd007d1e976680195ff50bd4a870";
    hash = "sha256-i0TI2SO9O7Zi5Ni07bZrB8jJxsAnjM4/095rjT0iuIw=";
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
