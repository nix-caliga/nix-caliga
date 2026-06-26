{ inputs, pkgs, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  layeredImage = {
    name = "ghcr.io/example/agenix";
    tag = "latest";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:a7f0ccdc982acf78351fc3f425729d1f45e2779b69201350ebff207730ab3a29";
      hash = "sha256-cJO4HhJkY+6kUu757PUBdQabjGLxollJV2W1iyq2TBY=";
      finalImageTag = "44";
    };
  };

  caliga.os = "fedora";
  caliga.core.enable = true;
  system.stateVersion = "25.11";

  users.users.root.hashedPassword = "";


  age.secrets.example.file = ../../secrets/example.age;
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # reference the secret:
  # config.age.secrets.example.path
}
