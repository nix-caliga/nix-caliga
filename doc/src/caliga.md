# Nix-caliga options

All nix-caliga options are disabled by default.  
You can pick and choose which parts of nix-caliga you want to make use of.

## Setting Base Image OS

`config.caliga.os` is optional, can be left empty.  
Selects the base operating system of the bootc image. This sets OS-specific defaults such as SELinux, and system group GIDs to match those already present in the base image.

Currently Available:
- Fedora [Fedora bootc base images](https://gitlab.com/fedora/bootc/base-images)
- Bluefin-dakota [projectbluefin/dakota](https://github.com/projectbluefin/dakota)

## Enabling All Core Options

`config.caliga.core.enable` enables all core modules: `etc-usr`, `systemd`, `tmpfiles`, and `users`.  
SELinux is controlled separately through `config.caliga.core.selinux.enable` and is set automatically based on `config.caliga.os`.

## Individual Core Modules

Each module can be enabled independently:

- `config.caliga.core.etc-usr.enable`
  - Enables `/etc` and `/usr` file generation. Required by most other modules. See [etc-usr](etc-usr.md).
- `config.caliga.core.systemd.enable`
  - Enables systemd unit generation. See [systemd](systemd.md).
- `config.caliga.core.tmpfiles.enable`
  - Enables `config.systemd.tmpfiles` rule management.
- `config.caliga.core.users.enable`
  - Enables user and group management through userborn. See [users-groups](users-groups.md).
- `config.caliga.core.selinux.enable`
  - Enables SELinux file context labeling. See [selinux](selinux.md).

## Environment

- `config.caliga.core.environment.linkCurrentSystem`
  - Create a `/run/current-system/sw` symlink to `config.system.path` so NixOS and home-manager modules referencing `/run/current-system/sw/bin` resolve. Defaults to `true`. See [etc-usr](etc-usr.md).

## Containerfile

`config.caliga.core.containerfile` configures an optional `podman build` step that runs after `streamLayeredImage`. Some operations (such as initramfs regeneration) cannot be done inside `streamLayeredImage` and require a Containerfile instead. See [buildImage](buildImage.md).

- `config.caliga.core.containerfile.enable`
  - Apply a Containerfile on top of the `streamLayeredImage` output. Defaults to `false`.
- `config.caliga.core.containerfile.file`
  - Path to a custom Containerfile. If set, takes full precedence — any commands from `config.caliga.core.containerfile.extraCommands` or generated commands (e.g. from `config.bootc.initramfs.regenerate.enable`) are not used.
- `config.caliga.core.containerfile.extraCommands`
  - Additional Containerfile commands appended to generated commands. Ignored if `config.caliga.core.containerfile.file` is set.
