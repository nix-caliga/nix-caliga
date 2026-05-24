{ pkgs, ... }:

{
  layeredImage = {
    name = "ghcr.io/example/microvm-host";
    tag = "latest";
    maxLayers = 125;
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "quay.io/fedora/fedora-bootc";
      imageDigest = "sha256:9d7a12d886dd2a50589d141b3d71d5dad520b3e131680356dccd484bc171e03e";
      hash = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
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
