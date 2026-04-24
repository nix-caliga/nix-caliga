{
  lib,
  config,
  ...
}:
{
  imports = [
    ./fedora
    ./bluefinDakota
  ];

  options.caliga.os = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "fedora"
        "bluefin-dakota"
      ]
    );
    default = null;
    description = ''
      The base operating system of the bootc image.

      Available options:
        fedora: https://gitlab.com/fedora/bootc/base-images
        bluefin-dakota: https://github.com/projectbluefin/dakota
    '';
  };

  config.warnings = lib.optional (config.caliga.os == null) ''
    caliga.os is not set. It is recommended to set it to one.
  '';
}
