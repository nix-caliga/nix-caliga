{
  lib,
  config,
  pkgs,
  ...
}:

let
  imgCfg = config.layeredImage;
in
{
  imports = [
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

    build.contents = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of derivations for streamLayeredImage contents.";
    };

    build.image = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The final image script (Either streamLayeredImage, or streamLayeredImage followed with postBuild.containerfile).";
    };

    # Not sure this should be handled by nix-caliga, but it is opt in.
    # If enabled, it takes the image built by nix, and runs it over with a contaienrfile in podman.
    # streamLayeredImage is limited in the changes it can make. It can't regen the initramfs for example.
    build.postBuild.containerfile = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Apply a Containerfile on top of the streamLayeredImage output.";
      };
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a Containerfile. Takes precedence over containerfile.extraCommands and generated commands if set.";
      };
      extraCommands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Containerfile commands included in the postBuild.";
      };
      _generatedFile = lib.mkOption {
        type = lib.types.path;
        readOnly = true;
        description = "Generated Containerfile path built from extraCommands.";
      };
    };

    build.imageArgs = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Final attrset passed to streamLayeredImage.";
    };

    layeredImage = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "The full image name (e.g. ghcr.io/org/image).";
      };

      tag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Image tag.";
      };

      maxLayers = lib.mkOption {
        type = lib.types.int;
        default = 80;
        description = "Maximum number of layers in the image.";
      };

      fromImage = lib.mkOption {
        type = lib.types.package;
        description = "Base image to layer on top of.";
        example = lib.literalExpression ''
          pkgs.dockerTools.pullImage {
            imageName = "quay.io/centos-bootc/centos-bootc";
            imageDigest = "sha256:abc123...";
            sha256 = "sha256-...";
            finalImageTag = "stream9";
          }
        '';
      };

      extraContents = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Extra derivations to include in the image contents.";
      };

      created = lib.mkOption {
        type = lib.types.str;
        default = "1970-01-01T00:00:01Z";
        description = "Timestamp for the image creation date.";
      };

      extraCommands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shell commands to run after creating the layer directory.";
      };

      fakeRootCommands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Shell commands to run inside a fakeroot environment. Useful for setting file ownership.
          See enableFakechroot.
        '';
      };

      enableFakechroot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to run fakeRootCommands in a fakechroot environment.";
      };

      includeStorePaths = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to include Nix store paths in the image.";
      };

      includeNixDB = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to include the Nix database in the image.";
      };

      config = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "OCI container config (Cmd, Env, Labels, Entrypoint, etc.).";
      };
    };
  };

  config = {
    assertions =
      let
        enabledUnitNames = lib.attrNames (lib.filterAttrs (_: u: u.enable) config.systemd.units);
        overlap = lib.intersectLists enabledUnitNames config.systemd.maskedUnits;
      in
      lib.optionals config.caliga.core.systemd.enable [
        {
          # TODO moving this next commit, why is it here
          assertion = overlap == [ ];
          message = "units cannot be both defined and masked: ${lib.concatStringsSep ", " overlap}";
        }
      ];

    build.postBuild.containerfile._generatedFile =
      pkgs.writeText "Containerfile" "FROM base\n${config.build.postBuild.containerfile.extraCommands}";

    build.image =
      let
        baseImage = pkgs.dockerTools.streamLayeredImage config.build.imageArgs;
        pbCfg = config.build.postBuild.containerfile;
      in
      if pbCfg.enable then
        let
          containerfile = if pbCfg.file != null then pbCfg.file else pbCfg._generatedFile;
        in
        pkgs.writeShellScript "stream-rebuilt-image" ''
          set -euo pipefail
          tmp=$(${pkgs.coreutils}/bin/mktemp -d)
          trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT
          ${baseImage} > "$tmp/base.tar"
          sudo ${pkgs.podman}/bin/podman build --from "docker-archive:$tmp/base.tar" -f ${containerfile} -t "${imgCfg.name}:${imgCfg.tag}" "$tmp" >&2
          sudo ${pkgs.podman}/bin/podman save "${imgCfg.name}:${imgCfg.tag}"
        ''
      else
        baseImage;

    build.contents = imgCfg.extraContents;

    layeredImage.config.Labels = lib.mkDefault {
      "containers.bootc" = "1";
      "ostree.bootable" = "true";
    };

    build.imageArgs = (removeAttrs imgCfg [ "extraContents" ]) // {
      contents = config.build.contents;
    };
  };
}
