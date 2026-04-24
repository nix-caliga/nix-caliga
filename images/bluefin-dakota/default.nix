{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/projectbluefin/dakota";
    tag = "latest";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "ghcr.io/projectbluefin/dakota";
      imageDigest = "sha256:1876990f38722642c241e2a765022984e87f8df1ef29a05aa4bd5f63f30cb924";
      hash = "sha256-C/tbOfuR/QP09qqvf3IrxjAj/Wj0WJsZbAQ9S6x9lJo=";
      finalImageTag = "latest";
    };
  };

  users.users.dakota = {
    isNormalUser = true;
    uid = 1001;
    initialPassword = "dakota";
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "25.11";

  caliga.os = "bluefin-dakota";
  caliga.core.enable = true;
}
