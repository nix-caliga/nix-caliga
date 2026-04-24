# tested only in podman for now, since dakota doesnt work with bootc-image-builder
# will do more testing in a vm/bare metal later
# but it works!
{
  lib,
  config,
  ...
}:
{
  imports = [
    ./users-groups.nix
  ];

  config = lib.mkIf (config.caliga.os == "bluefin-dakota") {
    caliga.core.selinux.enable = lib.mkDefault false;
    selinux.ignoreWarnings = lib.mkDefault true;

    assertions = [
      {
        assertion = !config.bootc.initramfs.regenerate;
        message = "bootc.initramfs.regenerate is not supported on bluefin-dakota";
      }
      {
        assertion = !config.bootc.ostree-prepare-root.createConf;
        message = "config.bootc.ostree-prepare-root.createConf is not supported on bluefin-dakota";
      }
    ];
  };
}
