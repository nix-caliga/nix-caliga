{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "fedora-kinoite";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora-ostree-desktops/kinoite";
      imageDigest = "sha256:8f5a379120358e463595cb0dfb46c3dcb50cc334b55704b73d3cedfe4eeab83d";
      hash = "sha256-53KUPqt2szNIzHS9qGoLa4IxMkjoP5sZnGvas8U2JwY=";
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
