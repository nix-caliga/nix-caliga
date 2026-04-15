# Generates /etc/selinux/targeted/contexts/files/file_contexts.local
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.selinux;

  nixStoreRules = {
    "/nix/store/[^/]+/etc(/.*)?" = "etc_t";
    "/nix/store/[^/]+/lib(/.*)?" = "lib_t";
    "/nix/store/[^/]+/lib/systemd/system(/.*)?" = "systemd_unit_file_t";
    "/nix/store/[^/]+/man(/.*)?" = "man_t";
    "/nix/store/[^/]+/s?bin(/.*)?" = "bin_t";
    "/nix/store/[^/]+/share(/.*)?" = "usr_t";
    "/nix/var/nix/daemon-socket(/.*)?" = "var_run_t";
    "/nix/var/nix/profiles(/per-user/[^/]+)?/[^/]+" = "usr_t";
  };

  allRules = (lib.optionalAttrs cfg.nixStoreContexts.enable nixStoreRules) // cfg.fileContexts;

  fileContextsLocal = pkgs.writeText "file_contexts.local" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (pattern: type: "${pattern}    system_u:object_r:${type}:s0") allRules
    )
    + "\n"
  );

  enforcementModeMap = {
    enforcing = "SELINUX=enforcing";
    permissive = "SELINUX=permissive";
    disabled = "SELINUX=disabled";
  };

in
{
  options.selinux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the SELinux module.";
    };

    enforcementMode = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "enforcing"
          "permissive"
          "disabled"
        ]
      );
      default = null;
      example = "enforcing";
      description = ''
        SELinux enforcement mode written to /etc/selinux/config.
        When null (default), the base image's configuration is left unchanged.
      '';
    };

    nixStoreContexts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add default SELinux file context rules for /nix/store paths.";
    };

    fileContexts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "/srv/app(/.*)?" = "httpd_sys_content_t";
      };
      description = ''
        Extra SELinux file context rules.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (allRules != { }) {
        environment.etc."selinux/targeted/contexts/files/file_contexts.local".source = fileContextsLocal;
      })

      (lib.mkIf (cfg.enforcementMode != null) {
        environment.etc."selinux/config".text = ''
          ${enforcementModeMap.${cfg.enforcementMode}}
          SELINUXTYPE=targeted
        '';
      })
    ]
  );
}
