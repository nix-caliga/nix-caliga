{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/nix-caliga/nix-caliga";
    tag = "test";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:850575ab43ae474135fa91dbf10b3a208ceaf0168158cff45fe2b37d2ee11fe9";
      sha256 = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
      finalImageTag = "43";
    };
  };

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

  systemd.defaultUnit = "multi-user.target";

  systemd.maskedUnits = [
    "sleep.target"
  ];

}
