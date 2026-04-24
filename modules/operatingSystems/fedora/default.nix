{
  lib,
  config,
  ...
}:
{
  imports = [
    ./users-groups.nix
  ];

  config = lib.mkIf (config.caliga.os == "fedora") {
    caliga.core.selinux.enable = lib.mkDefault true;
  };
}
