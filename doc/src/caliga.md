# Nix-caliga options

All nix-caliga options are disabled by default.  
You can pick and choose which parts of nix-caliga you want to make use of.

## `caliga.os`

Optional, can be left empty.  
Selects the base operating system of the bootc image. This sets OS-specific defaults such as SELinux, and system group GIDs to match those already present in the base image.

Currently Available:
- Fedora [Fedora bootc base images](https://gitlab.com/fedora/bootc/base-images)
- Bluefin-dakota [projectbluefin/dakota](https://github.com/projectbluefin/dakota)

## `caliga.core.enable`

Enables all core modules: `etc-usr`, `systemd`, `tmpfiles`, and `users`.  
SELinux is controlled separately through `caliga.core.selinux.enable` and is set automatically based on `caliga.os`.

## Individual core modules

Each module can be enabled independently:

- `caliga.core.etc-usr.enable` Enables `/etc` and `/usr` file generation. Required by most other modules. See [etc-usr](etc-usr.md).
- `caliga.core.systemd.enable` Enables systemd unit generation. See [systemd](systemd.md).
- `caliga.core.tmpfiles.enable` Enables `systemd.tmpfiles` rule management.
- `caliga.core.users.enable` Enables user and group management through userborn. See [users-groups](users-groups.md).
- `caliga.core.selinux.enable` Enables SELinux file context labeling. See [selinux](selinux.md).

## `caliga.core.containerfile`

An optional `podman build` step that runs after `streamLayeredImage`. Some operations (such as initramfs regeneration) cannot be done inside `streamLayeredImage` and require a Containerfile instead. See [buildImage](buildImage.md).

- `caliga.core.containerfile.enable` Apply a Containerfile on top of the `streamLayeredImage` output. Defaults to `false`.
- `caliga.core.containerfile.file` Path to a custom Containerfile. If set, takes full precedence any commands from `extraCommands` or generated commands (e.g. from `bootc.initramfs.regenerate`) are not used.
- `caliga.core.containerfile.extraCommands` Additional Containerfile commands appended to generated commands. Ignored if `file` is set.
