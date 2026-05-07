# SELinux
Fedora bootc images ship with SELinux enforcing by default. Nix store paths do not get SELinux context in the base image.

When `config.caliga.core.selinux.enable` is true, nix-caliga creates a file at `/etc/selinux/targeted/contexts/files/file_contexts.local` with rules that label common nix store subdirectories.
This file is placed using `config.environment.etc` as a real file, as SELinux needs it before the nix store is available.

## Nix Store Labels
The default nix store context rules (enabled by `config.selinux.nixStoreContexts.enable`) cover the standard layout used by nix-caliga:

- `/nix/store/<hash>/bin/`, `/nix/store/<hash>/sbin/` > `bin_t`
- `/nix/store/<hash>/lib/` > `lib_t`
- `/nix/store/<hash>/etc/` > `etc_t`
- `/nix/store/<hash>/share/`, `/nix/store/<hash>/usr/`, `/nix/var/nix/profiles/` > `usr_t`
- `/nix/store/<hash>/lib/systemd/system/`, `/nix/store/<hash>/usr/lib/systemd/system/` > `systemd_unit_file_t`
- `/nix/store/<hash>/man/` > `man_t`
- `/nix/var/nix/daemon-socket/` > `var_run_t`

This mostly follows the same SELinux types used by the nix-community/nix-installers SELinux policy, with a few additions for /usr and systemd.

## Service Exec Labels
Some NixOS modules produce scripts with `pkgs.writeShellScript` or `pkgs.writeTextFile` that end up at store paths that dont have a `/bin` or `/sbin`. This means the scripts do not get labels by default.  
The `config.selinux.labelServiceExecs` option accepts a list of systemd service names and it will extract all `Exec*` paths (`ExecStart`, `ExecStartPre`, etc.) from those services, and add `bin_t` rules for all nix store paths.

## Enforcement Mode
By default, the base image's SELinux enforcement mode is left unchanged. The `config.selinux.enforcementMode` option can override it by writing `/etc/selinux/config` with the specified mode.

## Custom File Contexts
Additional file context rules can be added with `config.selinux.fileContexts`:
```nix
selinux.fileContexts = {
  "/nix/store/[^/]+/etc(/.*)?" = "etc_t";
};
```

## Options

Enabled with `config.caliga.core.selinux.enable`.

- `config.selinux.nixStoreContexts.enable`
  - Default SELinux rules for `/nix/store` paths. Defaults to `true`.
- `config.selinux.labelServiceExecs`
  - List of systemd service names whose Exec store paths need to be labeled `bin_t`.
- `config.selinux.fileContexts`
  - Extra SELinux file context rules.
- `config.selinux.enforcementMode`
  - SELinux enforcement mode. Defers to the base image by default.
- `config.selinux.ignoreWarnings`
  - Suppress SELinux-related warnings from other modules.
