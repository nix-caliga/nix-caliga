{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "almalinux-bootc";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/almalinuxorg/almalinux-bootc";
      imageDigest = "sha256:0a036afe9ddfb987f2b5c428242ebeaf5c74d4279122f4ccf45dc7c38fe55c73";
      hash = "sha256-JG/5hZcHNW80XyV3AIAHqFst2kKpnw9mksUh2bqmf2c=";
      finalImageName = "quay.io/almalinuxorg/almalinux-bootc";
      finalImageTag = "10";
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
