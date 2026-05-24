# originally copied from numtide/system-manager.
{ config, lib, ... }:
{
  # Stub for an option referenced by the upstream wrappers module that we don't import.
  options.security.apparmor.includes = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    internal = true;
  };

  config = lib.mkIf config.security.enableWrappers {
    systemd.services.suid-sgid-wrappers.after = lib.mkForce [
      "userborn.service"
      "run-wrappers.mount"
    ];
  };
}
