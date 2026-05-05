# Build Image
Nix-caliga builds bootc-compatible OCI images using `pkgs.dockerTools.streamLayeredImage`. The module takes a base bootc image (Fedora-bootc, uBlue, etc), layers Nix store paths and configuration on top, and produces a streamable image script.

The final image script is available at `config.build.image`.

## streamLayeredImage
`pkgs.dockerTools.streamLayeredImage.*` options are made directly available at `config.layeredImage.*`. See the [NixOS Manual](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-streamLayeredImage).

The image is labeled with `containers.bootc = "1"` and `ostree.bootable = "true"` by default.

### streamLayeredImage limitations
`streamLayeredImage` only has access to the files built by streamLayeredImage.  
This means steps that need base image contents (initramfs regeneration, rpm operations, etc.) cannot run in fakeRootCommands. Use the containerfile option instead.

## Containerfile
When `caliga.core.containerfile.enable` is true, the build gains a second stage. After `streamLayeredImage` streams the base tar, podman runs a containerfile on top of it. This allows steps such as regenerating the initramfs for bootc's `prepare-root.conf` changes to take effect.

You can either provide a complete Containerfile with `caliga.core.containerfile.file`, or list commands with `caliga.core.containerfile.extraCommands`.  
Other modules may add to `caliga.core.containerfile.extraCommands` automatically. For example, `bootc.ostree-prepare-root.transientEtc` (see [bootc](bootc.md)) adds an initramfs regeneration command since `streamLayeredImage` alone cannot do this.
`caliga.core.containerfile.file` takes precedence over extraCommands if set.

# Options
## `build.image`
- The final image script. Read-only. Result is either the streamLayeredImage script, or a script with the streamLayeredImage script wrapped by a podman build with the containerfile.

## `layeredImage.*`
- `layeredImage.name`
  - The full image name (e.g. ghcr.io/org/image).
- `layeredImage.tag`
  - Image tag. Defaults to "latest".
- `layeredImage.maxLayers`
  - Maximum number of layers in the image. Defaults to 80.
- `layeredImage.fromImage`
  - Base image to layer on top of, typically from `pkgs.dockerTools.pullImage`.
- `layeredImage.contents`
  - Derivations to include in the image contents.
- `layeredImage.created`
  - Timestamp for the image creation date.
- `layeredImage.extraCommands`
  - Shell commands to run after creating the layer directory.
- `layeredImage.fakeRootCommands`
  - Shell commands to run inside a fakeroot environment.
- `layeredImage.enableFakechroot`
  - Whether to run fakeRootCommands in a fakechroot environment.
- `layeredImage.includeStorePaths`
  - Whether to include Nix store paths in the image. Defaults to true.
- `layeredImage.includeNixDB`
  - Whether to include the Nix database in the image. Useful if running the nix daemon on the target system. Defaults to false.
- `layeredImage.config`
  - OCI container config (Cmd, Env, Labels, Entrypoint, etc.).

## `caliga.core.containerfile.*`
- `caliga.core.containerfile.enable`
  - Apply a Containerfile on top of the streamLayeredImage output.
- `caliga.core.containerfile.file`
  - Path to a Containerfile. Takes precedence over extraCommands if set.
- `caliga.core.containerfile.extraCommands`
  - Containerfile commands included alongside generated commands. Applied after streamLayeredImage.
