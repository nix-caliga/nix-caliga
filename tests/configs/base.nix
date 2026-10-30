{ pkgs, ... }:
{
  layeredImage.fromImage = pkgs.dockerTools.pullImage {
    imageName = "quay.io/fedora/fedora-bootc";
    imageDigest = "sha256:e4ae31668bb611e551b63f66a05a4962fee1f887d485c02ec5af09e818499608";
    hash = "sha256-l318JY+T7ASNypM2pG3QeXYcvFPfau4vrVCF/4vRpkE=";
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
