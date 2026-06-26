{ inputs, pkgs, ... }:

{
  imports = [ inputs.microvm.nixosModules.host ];

  layeredImage = {
    name = "ghcr.io/example/microvm-host";
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

  microvm.vms.myvm = {
    autostart = true;
    config = {
      networking.hostName = "myvm";
      system.stateVersion = "25.11";

      users.users.root.password = "";

      microvm = {
        hypervisor = "qemu";
        vcpu = 1;
        mem = 512;

        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];

        volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 256;
          }
        ];
      };
    };
  };
}
