# Fedora bootc base image users and groups
# GIDs match Fedora defaults to avoid conflicts with pre-existing system groups.
# To add a user to a group via extraGroups, the group must be declared here.
{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.caliga.os == "fedora" && config.caliga.core.users.enable) {
    users.users = {
      root = {
        uid = 0;
        description = "System administrator";
        home = "/root";
        shell = lib.mkDefault config.users.defaultUserShell;
        group = "root";
      };
      nobody = {
        uid = lib.mkDefault 99;
        isSystemUser = true;
        description = "Kernel Overflow User";
        group = "nobody";
      };
    };

    users.groups = {
      root.gid = lib.mkDefault 0;
      wheel.gid = lib.mkDefault 10;
      disk.gid = lib.mkDefault 6;
      kmem.gid = lib.mkDefault 9;
      tty.gid = lib.mkDefault 5;
      lp.gid = lib.mkDefault 7;
      cdrom.gid = lib.mkDefault 11;
      tape.gid = lib.mkDefault 33;
      audio.gid = lib.mkDefault 63;
      video.gid = lib.mkDefault 39;
      dialout.gid = lib.mkDefault 18;
      nobody.gid = lib.mkDefault 99;
      users.gid = lib.mkDefault 100;
      utmp.gid = lib.mkDefault 22;
      adm.gid = lib.mkDefault 4;
      input.gid = lib.mkDefault 104;
      kvm.gid = lib.mkDefault 36;
      render.gid = lib.mkDefault 105;
      sgx.gid = lib.mkDefault 106;
      man.gid = lib.mkDefault 15;
      floppy.gid = lib.mkDefault 19;
      tss.gid = lib.mkDefault 59;
      shadow.gid = lib.mkDefault 65533; # required by userborn in mutable mode, TODO make sure the id isn't a bad pick
    };
  };
}
