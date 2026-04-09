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
    ./etc.nix
    ./tmpfiles.nix
    ./systemd
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
      description = "The final streamLayeredImage derivation.";
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
      [
        {
          assertion = overlap == [ ];
          message = "units cannot be both defined and masked: ${lib.concatStringsSep ", " overlap}";
        }
      ];

    build.image = pkgs.dockerTools.streamLayeredImage config.build.imageArgs;

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
