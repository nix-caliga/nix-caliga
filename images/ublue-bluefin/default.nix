{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "ublue-bluefin";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/ublue-os/bluefin";
      imageDigest = "sha256:ec4325b7ee3325fcacc91d3ebfa68e1e43ac382c502618705784419e9e98b93e";
      hash = "sha256-iwWhY8BiB0yhHmGo05m17EV7LqCC8aDGuCLHxdH0gTU=";
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
