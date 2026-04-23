# copied from system-manager's nix/modules/etc.nix
# changes: uses fakeRootCommands to copy files as real files (not store symlinks)
#   mode default changed from "symlink" to "0644", overlay stub
#   added environment.usr identical to environment.etc but for /usr
{
  lib,
  config,
  pkgs,
  ...
}:
let
  mkFileOption =
    prefix:
    lib.mkOption {
      default = { };
      example = lib.literalExpression ''
        { "some/config-file" =
            { source = "/nix/store/.../file.conf";
              mode = "0440";
            };
          "default/useradd".text = "GROUP=100 ...";
        }
      '';
      description = lib.mdDoc ''
        Set of files to be placed in {file}`/${prefix}`.
      '';

      type = lib.types.attrsOf (
        lib.types.submodule (
          {
            name,
            config,
            options,
            ...
          }:
          {
            options = {

              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = lib.mdDoc ''
                  Whether this /${prefix} file should be generated.  This
                  option allows specific /${prefix} files to be disabled.
                '';
              };

              target = lib.mkOption {
                type = lib.types.str;
                description = lib.mdDoc ''
                  Path relative to {file}`/${prefix}`.
                  Defaults to the attribute name.
                '';
              };

              text = lib.mkOption {
                default = null;
                type = lib.types.nullOr lib.types.lines;
                description = lib.mdDoc "Text of the file.";
              };

              source = lib.mkOption {
                type = lib.types.path;
                description = lib.mdDoc "Path of the source file.";
              };

              mode = lib.mkOption {
                type = lib.types.str;
                default = "0644";
                example = "0600";
                description = lib.mdDoc ''
                  The file mode for the copied file.
                '';
              };

              uid = lib.mkOption {
                default = 0;
                type = lib.types.int;
                description = lib.mdDoc ''
                  UID of created file. Only takes effect when the file is
                  copied (that is, the mode is not 'symlink').
                '';
              };

              gid = lib.mkOption {
                default = 0;
                type = lib.types.int;
                description = lib.mdDoc ''
                  GID of created file. Only takes effect when the file is
                  copied (that is, the mode is not 'symlink').
                '';
              };

              user = lib.mkOption {
                default = "+${toString config.uid}";
                type = lib.types.str;
                description = lib.mdDoc ''
                  User name of created file.
                  Only takes effect when the file is copied (that is, the mode is not 'symlink').
                  Changing this option takes precedence over `uid`.
                '';
              };

              group = lib.mkOption {
                default = "+${toString config.gid}";
                type = lib.types.str;
                description = lib.mdDoc ''
                  Group name of created file.
                  Only takes effect when the file is copied (that is, the mode is not 'symlink').
                  Changing this option takes precedence over `gid`.
                '';
              };
            };

            config = {
              target = lib.mkDefault name;
              source = lib.mkIf (config.text != null) (
                let
                  name' = "${prefix}-" + baseNameOf name;
                in
                lib.mkDerivedConfig options.text (pkgs.writeText name')
              );
            };
          }
        )
      );
    };

  mkFakeRootCommands =
    prefix: files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_: f: ''
        if [ -d ${f.source} ]; then
          mkdir -p ${prefix}/${f.target}
          for file in $(find -L ${f.source} -type f); do
            rel="''${file#${f.source}/}"
            install -D -m ${f.mode} -o ${f.user} -g ${f.group} "$file" "${prefix}/${f.target}/$rel"
          done
        else
          mkdir -p ${prefix}/$(dirname "${f.target}")
          install -m ${f.mode} -o ${f.user} -g ${f.group} ${f.source} ${prefix}/${f.target}
        fi
      '') files
    );
in
{
  options = {
    system.etc.overlay.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Stub. NixOS specific option.
        To configure bootc /etc behaviour, see `bootc.ostree-prepare-root.transientEtc`.
      '';
    };

    environment.etc = mkFileOption "etc";
    environment.usr = mkFileOption "usr";
  };
  config =
    let
      filteredEtc = lib.filterAttrs (_: f: f.enable) config.environment.etc;
      filteredUsr = lib.filterAttrs (_: f: f.enable) config.environment.usr;
      hasEtc = filteredEtc != { };
      hasUsr = filteredUsr != { };
      hasFiles = hasEtc || hasUsr;
    in
    lib.mkIf config.caliga.core.etc.enable {
      warnings =
        lib.optional (hasEtc && !config.caliga.core.selinux.enable && !config.selinux.ignoreWarnings)
          ''
            caliga.core.etc.enable is active but caliga.core.selinux.enable is false.
            Files written to /etc may not be usable if selinux is enforcing.
            Enable caliga.core.selinux.enable or set selinux.ignoreWarnings = true to silence this warning.
          '';

      layeredImage.enableFakechroot = lib.mkIf hasFiles true;

      layeredImage.fakeRootCommands =
        lib.optionalString hasEtc (mkFakeRootCommands "etc" filteredEtc)
        + lib.optionalString (hasEtc && hasUsr) "\n"
        + lib.optionalString hasUsr (mkFakeRootCommands "usr" filteredUsr);
    };
}
