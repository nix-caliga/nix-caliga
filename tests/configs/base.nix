{ pkgs, ... }:
{
  layeredImage.fromImage = pkgs.dockerTools.pullImage {
    imageName = "quay.io/fedora/fedora-bootc";
    imageDigest = "sha256:dc1055df531e11ea6753af22414cb7ff217023e93d68cca3f92198df6214f9ee";
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
