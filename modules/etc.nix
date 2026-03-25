# copied from system-manager's nix/modules/etc.nix
# changes: uses fakeRootCommands to copy etc files as real files (not store symlinks)
#   mode default changed from "symlink" to "0644", overlay stub
{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    # stub: referenced by upstream nixpkgs modules?
    system.etc = {
      overlay = {
        enable = lib.mkEnableOption "/etc overlay";
      };
    };

    environment.etc = lib.mkOption {
      default = { };
      example = lib.literalExpression ''
        { example-configuration-file =
            { source = "/nix/store/.../etc/dir/file.conf.example";
              mode = "0440";
            };
          "default/useradd".text = "GROUP=100 ...";
        }
      '';
      description = lib.mdDoc ''
        Set of files that have to be linked in {file}`/etc`.
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
                  Whether this /etc file should be generated.  This
                  option allows specific /etc files to be disabled.
                '';
              };

              target = lib.mkOption {
                type = lib.types.str;
                description = lib.mdDoc ''
                  Name of symlink (relative to
                  {file}`/etc`).  Defaults to the attribute
                  name.
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

              replaceExisting = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = lib.mdDoc ''
                  Whether to replace a pre-existing file at the target path.
                '';
              };
            };

            config = {
              target = lib.mkDefault name;
              source = lib.mkIf (config.text != null) (
                let
                  name' = "etc-" + baseNameOf name;
                in
                lib.mkDerivedConfig options.text (pkgs.writeText name')
              );
            };
          }
        )
      );
    };
  };
  config =
    let
      filteredEtc = lib.filterAttrs (_: f: f.enable) config.environment.etc;
      hasEtc = filteredEtc != { };
    in
    {
      system.etc.overlay.enable = false;

      layeredImage.enableFakechroot = lib.mkIf hasEtc true;

      layeredImage.fakeRootCommands = lib.mkIf hasEtc (
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (_: f: ''
            if [ -d ${f.source} ]; then
              mkdir -p etc/${f.target}
              for file in $(find -L ${f.source} -type f); do
                rel="''${file#${f.source}/}"
                install -D -m ${f.mode} -o ${f.user} -g ${f.group} "$file" "etc/${f.target}/$rel"
              done
            else
              mkdir -p etc/$(dirname "${f.target}")
              install -m ${f.mode} -o ${f.user} -g ${f.group} ${f.source} etc/${f.target}
            fi
          '') filteredEtc
        )
      );
    };
}
