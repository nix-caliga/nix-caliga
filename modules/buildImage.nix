{
  lib,
  config,
  pkgs,
  ...
}:

let
  imgCfg = config.layeredImage;

  imageArgs = {
    inherit (imgCfg)
      name
      tag
      maxLayers
      fromImage
      contents
      created
      extraCommands
      fakeRootCommands
      enableFakechroot
      includeStorePaths
      includeNixDB
      config
      ;
  };
in
{
  options = {

    build.image = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The final image script (Either streamLayeredImage, or streamLayeredImage followed with a containerfile).";
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

      contents = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Derivations to include in the image contents.";
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
    build.image =
      let
        baseImage = pkgs.dockerTools.streamLayeredImage imageArgs;
        pbCfg = config.caliga.core.containerfile;
      in
      if pbCfg.enable then
        let
          containerfile =
            if pbCfg.file != null then pbCfg.file
            else pkgs.writeText "Containerfile" "FROM base\n${pbCfg.extraCommands}";
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

    layeredImage.config.Labels = lib.mkDefault {
      "containers.bootc" = "1";
      "ostree.bootable" = "true";
    };

  };
}
