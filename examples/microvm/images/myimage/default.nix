{ inputs, pkgs, ... }:

{
  imports = [ inputs.microvm.nixosModules.host ];

  layeredImage = {
    name = "ghcr.io/example/microvm-host";
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

        # Share the host's Nix store read-only into the VM.
        # The host must bind-mount /nix/store into the VM's virtiofs socket path.
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
