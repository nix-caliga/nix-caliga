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

  # Extract Exec store paths from selected services and label as bin_t.
  # Handles writeShellScript etc which will be missed by default labels
  execs = [ "ExecStart" "ExecStartPre" "ExecStartPost" "ExecReload" "ExecStop" "ExecStopPost" ];
  getExecs = svc: exec:
    if svc.serviceConfig ? ${exec}
    then map toString (lib.toList svc.serviceConfig.${exec})
    else [ ];

  # Strip prefixes and check for store path
  cleanPath = s: builtins.head (builtins.match "[!@+-]*(.*)" s);
  inStore = p: builtins.match "/nix/store/[^/]+" (cleanPath p) != null;

  execLabelRules = lib.listToAttrs (
    map (p: { name = builtins.unsafeDiscardStringContext (cleanPath p); value = "bin_t"; })
      (lib.unique (lib.filter inStore (
        lib.concatMap (name:
          lib.concatMap (getExecs config.systemd.services.${name}) execs
        ) cfg.labelServiceExecs
      )))
  );

  allRules =
    (lib.optionalAttrs cfg.nixStoreContexts.enable nixStoreRules)
    // cfg.fileContexts
    // execLabelRules;

  fileContextsLocal = pkgs.writeText "file_contexts.local" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (pattern: type: "${pattern}    system_u:object_r:${type}:s0") allRules
    )
    + "\n"
  );

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

    labelServiceExecs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nftables" ];
      description = ''
        List of systemd service names whose Exec store paths need to be labeled bin_t.
        Only needed for services that execute nix store paths not already grabbed by default rules.
      '';
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
        environment.etc."selinux/config".text = lib.concatStringsSep "\n" [
          "SELINUX=${cfg.enforcementMode}"
          "SELINUXTYPE=targeted"
          ""
        ];
      })
    ]
  );
}
