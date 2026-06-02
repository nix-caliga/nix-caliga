{ pkgs, ... }:

{
  config = {
    layeredImage = {
      # This is the name of the resulting image you make
      name = "ghcr.io/nix-caliga/nix-caliga";
      # This is the tag of the resulting image you make
      tag = "tag";
      fromImage = pkgs.dockerTools.pullImage {
        # These come from nix-prefetch-docker
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:3a6b31238244f72a531a64f5fa0c102fcc1c64afcf0277f09fe85a8d6b0256d1";
        hash = "sha256-jCBPY70czkZm3D9z4js+Cj0BVirRoIequOau/Ctv9zg=";
        finalImageTag = "43";
      };
    };

    # set your base image OS
    caliga.os = "fedora";
    # this enables all core modules for nix-caliga
    caliga.core.enable = true;
    # set the current nixos version
    system.stateVersion = "25.11";

    # set your username
    users.users.yourUser = {
      isNormalUser = true;
      uid = 1001;
      description = "Example User";
      # This will set your password at first login, it can be changed afterward
      initialPassword = "password";
    };

    # a list of nixpkgs you want available to all users
    environment.systemPackages = [
      pkgs.cowsay
      pkgs.nixfmt
    ];
  };
}
