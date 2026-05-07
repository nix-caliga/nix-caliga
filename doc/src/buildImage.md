# Build Image
Nix-caliga builds bootc-compatible OCI images using `pkgs.dockerTools.streamLayeredImage`. The module takes a base bootc image (Fedora-bootc, uBlue, etc), layers Nix store paths and configuration on top, and produces a streamable image script.

The final image script is available at `config.build.image`.

## StreamLayeredImage
`pkgs.dockerTools.streamLayeredImage.*` options are made directly available at `config.layeredImage.*`. See the [NixOS Manual](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-streamLayeredImage).

The image is labeled with `containers.bootc = "1"` and `ostree.bootable = "true"` by default.

### Limitations
`streamLayeredImage` only has access to the files built by `streamLayeredImage`.  
This means steps that need base image contents (initramfs regeneration, rpm operations, etc.) cannot run in `streamLayeredImage.fakeRootCommands`. Use the containerfile option instead.

## Containerfile
When `config.caliga.core.containerfile.enable` is true, the build gains a second stage. After `streamLayeredImage` streams the base tar, podman runs a containerfile on top of it. This allows steps such as regenerating the initramfs for bootc's `prepare-root.conf` changes to take effect.

You can either provide a complete Containerfile with `config.caliga.core.containerfile.file`, or list commands with `config.caliga.core.containerfile.extraCommands`.  
Other modules may add to `config.caliga.core.containerfile.extraCommands` automatically. For example, `config.bootc.ostree-prepare-root.transientEtc` (see [bootc](bootc.md)) adds an initramfs regeneration command since `streamLayeredImage` alone cannot do this.
`config.caliga.core.containerfile.file` takes precedence over `config.caliga.core.containerfile.extraCommands` if set.

## Options

### `config.build.image`
- The final image script. Read-only. Result is either the `streamLayeredImage` script, or a script with the `streamLayeredImage` script wrapped by a podman build with the containerfile.

### `config.layeredImage.*`
- `config.layeredImage.name`
  - The full image name (e.g. ghcr.io/org/image).
- `config.layeredImage.tag`
  - Image tag. Defaults to "latest".
- `config.layeredImage.maxLayers`
  - Maximum number of layers in the image. Defaults to `80`.
- `config.layeredImage.fromImage`
  - Base image to layer on top of, typically from `pkgs.dockerTools.pullImage`.
- `config.layeredImage.contents`
  - Derivations to include in the image contents.
- `config.layeredImage.created`
  - Timestamp for the image creation date.
- `config.layeredImage.extraCommands`
  - Shell commands to run after creating the layer directory.
- `config.layeredImage.fakeRootCommands`
  - Shell commands to run inside a fakeroot environment.
- `config.layeredImage.enableFakechroot`
  - Whether to run `config.layeredImage.fakeRootCommands` in a fakechroot environment.
- `config.layeredImage.includeStorePaths`
  - Whether to include Nix store paths in the image. Defaults to `true`.
- `config.layeredImage.includeNixDB`
  - Whether to include the Nix database in the image. Useful if running the nix daemon on the target system. Defaults to `false`.
- `config.layeredImage.config`
  - OCI container config (Cmd, Env, Labels, Entrypoint, etc.).

### `config.caliga.core.containerfile.*`
- `config.caliga.core.containerfile.enable`
  - Apply a Containerfile on top of the `streamLayeredImage` output.
- `config.caliga.core.containerfile.file`
  - Path to a Containerfile. Takes precedence over `config.caliga.core.containerfile.extraCommands` if set.
- `config.caliga.core.containerfile.extraCommands`
  - Containerfile commands included alongside generated commands. Applied after `streamLayeredImage`.
