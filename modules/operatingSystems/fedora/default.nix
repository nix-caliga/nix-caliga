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

    # some fedora related distros (almalinux) don't appear to ship the default nixos cert file `/etc/ssl/certs/ca-certificates.crt
    nix.settings.ssl-cert-file = lib.mkDefault "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem";
  };
}
