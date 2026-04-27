# originally copied from system-manager's nix/modules/etc.nix
#
# files with the default mode are symlinked to their location in /etc or /usr using layeredImage.contents
# files that are used early in boot, (prepare-root.conf, selinux configs etc) don't work as symlinks and need real files
# if a mode is set (0600 etc) then the file is placed using fakeRootCommands and does not show up in layeredImage.contents
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
                  Whether this /${prefix} file should be created.
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
                default = "symlink";
                example = "0600";
                description = lib.mdDoc ''
                  If `symlink`, the file is symlinked via layeredImage.contents.
                  Otherwise, the file is copied as a real file with the given mode via fakeRootCommands and uid/gid/user/group take effect.
                  Set an explicit mode for files read at install-time or early boot (selinux, ostree-prepare-root, etc).
                '';
              };

              uid = lib.mkOption {
                default = 0;
                type = lib.types.int;
                description = lib.mdDoc ''
                  UID of created file.
                '';
              };

              gid = lib.mkOption {
                default = 0;
                type = lib.types.int;
                description = lib.mdDoc ''
                  GID of created file.
                '';
              };

              user = lib.mkOption {
                default = "+${toString config.uid}";
                type = lib.types.str;
                description = lib.mdDoc ''
                  User name of created file. Takes precedence over `uid`.
                '';
              };

              group = lib.mkOption {
                default = "+${toString config.gid}";
                type = lib.types.str;
                description = lib.mdDoc ''
                  Group name of created file. Takes precedence over `gid`.
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
  # real files are placed with fakeRootCommands
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
          install -D -m ${f.mode} -o ${f.user} -g ${f.group} ${f.source} ${prefix}/${f.target}
        fi
      '') files
    );
  # default mode, symlinked files are placed with layeredImage.contents
  mkContents =
    prefix: files:
    pkgs.runCommand "${prefix}-files"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      (lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_: f: ''
          if [ -d ${f.source} ]; then
            mkdir -p $out/${prefix}/${f.target}
            cp -rL ${f.source}/. $out/${prefix}/${f.target}/
          else
            mkdir -p $out/${prefix}/${builtins.dirOf f.target}
            cp -L ${f.source} $out/${prefix}/${f.target}
          fi
        '') files
      ));
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
      sort =
        files:
        let
          enabled = lib.filterAttrs (_: f: f.enable) files;
        in
        {
          symlink = lib.filterAttrs (_: f: f.mode == "symlink") enabled;
          file = lib.filterAttrs (_: f: f.mode != "symlink") enabled;
        };

      etcParts = sort config.environment.etc;
      usrParts = sort config.environment.usr;

      hasEtcSymlink = etcParts.symlink != { };
      hasUsrSymlink = usrParts.symlink != { };
      hasEtcFile = etcParts.file != { };
      hasUsrFile = usrParts.file != { };
    in
    lib.mkIf config.caliga.core.etc-usr.enable {
      warnings =
        lib.optional (
          (hasEtcSymlink || hasUsrSymlink)
          && !config.caliga.core.selinux.enable
          && !config.selinux.ignoreWarnings
        ) ''
          caliga.core.etc-usr.enable has symlink entries but caliga.core.selinux.enable is false.
          Symlinks in /etc and /usr resolve into /nix/store paths that the base image's SELinux policy likely does not cover;

          Enable caliga.core.selinux.enable or set selinux.ignoreWarnings = true to silence this warning.
        '';

      layeredImage.enableFakechroot = lib.mkIf (hasEtcFile || hasUsrFile) true;

      layeredImage.fakeRootCommands =
        lib.optionalString hasEtcFile (mkFakeRootCommands "etc" etcParts.file)
        + lib.optionalString (hasEtcFile && hasUsrFile) "\n"
        + lib.optionalString hasUsrFile (mkFakeRootCommands "usr" usrParts.file);

      layeredImage.contents =
        lib.optional hasEtcSymlink (mkContents "etc" etcParts.symlink)
        ++ lib.optional hasUsrSymlink (mkContents "usr" usrParts.symlink);
    };
}
