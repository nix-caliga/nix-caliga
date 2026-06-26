{ inputs, pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/example/bootc-image-prefetcher";
    tag = "latest";
    fromImage = pkgs.dockerTools.pullImage inputs.bootc-image-prefetcher.pins.fedora-base-atomic."44";
  };

  caliga.os = "fedora";
  caliga.core.enable = true;
  system.stateVersion = "26.04";

}
