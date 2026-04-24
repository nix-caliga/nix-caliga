# Universal Blue Dakota (GNOME OS) base image users and groups
# GIDs match Dakota defaults to avoid conflicts with pre-existing system groups.
# To add a user to a group via extraGroups, the group must be declared here.
{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.caliga.os == "bluefin-dakota" && config.caliga.core.users.enable) {
    users.users = {
      root = {
        uid = 0;
        description = "System administrator";
        home = "/root";
        shell = lib.mkDefault config.users.defaultUserShell;
        group = "root";
      };
      nobody = {
        uid = lib.mkDefault 65534;
        isSystemUser = true;
        description = "Kernel Overflow User";
        group = "nobody";
      };
    };

    users.groups = {
      root.gid = lib.mkDefault 0;
      wheel.gid = lib.mkDefault 997;
      disk.gid = lib.mkDefault 990;
      kmem.gid = lib.mkDefault 988;
      tty.gid = lib.mkDefault 5;
      uucp.gid = lib.mkDefault 14;
      lp.gid = lib.mkDefault 986;
      cdrom.gid = lib.mkDefault 993;
      tape.gid = lib.mkDefault 983;
      audio.gid = lib.mkDefault 994;
      video.gid = lib.mkDefault 982;
      dialout.gid = lib.mkDefault 991;
      nobody.gid = lib.mkDefault 65534;
      users.gid = lib.mkDefault 100;
      utmp.gid = lib.mkDefault 995;
      adm.gid = lib.mkDefault 998;
      input.gid = lib.mkDefault 989;
      kvm.gid = lib.mkDefault 987;
      render.gid = lib.mkDefault 985;
      sgx.gid = lib.mkDefault 984;
      shadow.gid = lib.mkDefault 15;
    };
  };
}
