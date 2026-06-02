{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/example/agenix";
    tag = "latest";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:3a6b31238244f72a531a64f5fa0c102fcc1c64afcf0277f09fe85a8d6b0256d1";
      hash = "sha256-jCBPY70czkZm3D9z4js+Cj0BVirRoIequOau/Ctv9zg=";
      finalImageTag = "43";
    };
  };

  caliga.os = "fedora";
  caliga.core.enable = true;
  system.stateVersion = "25.11";

  users.users.root.hashedPassword = "";

  # obviously you use a real device specific key
  environment.etc."ssh/ssh_host_ed25519_key" = {
    source = ./test_host_key;
    mode = "0600";
  };

  age.secrets.example.file = ../../secrets/example.age;
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
