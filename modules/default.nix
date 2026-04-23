{
  lib,
  ...
}:

{
  imports = [
    ./buildImage.nix
    ./caliga.nix
    ./etc.nix
    ./tmpfiles.nix
    ./systemd
    ./bootc.nix
    ./bootc-update.nix
    ./selinux.nix
    ./nix.nix
    ./upstream/nixpkgs
  ];

  options = {

    assertions = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      internal = true;
      default = [ ];
      example = [
        {
          assertion = false;
          message = "you can't enable this for that reason";
        }
      ];
      description = ''
        This option allows modules to express conditions that must
        hold for the evaluation of the system configuration to
        succeed, along with associated error messages for the user.
      '';
    };

    warnings = lib.mkOption {
      internal = true;
      default = [ ];
      type = lib.types.listOf lib.types.str;
      example = [ "The `foo' service is deprecated and will go away soon!" ];
      description = ''
        This option allows modules to show warnings to users during
        the evaluation of the system configuration.
      '';
    };
  };
}
