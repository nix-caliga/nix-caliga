{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "fedora-bootc";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:a7f0ccdc982acf78351fc3f425729d1f45e2779b69201350ebff207730ab3a29";
      hash = "sha256-cJO4HhJkY+6kUu757PUBdQabjGLxollJV2W1iyq2TBY=";
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
