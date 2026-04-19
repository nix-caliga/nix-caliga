# TODO cli is essencially raw vibes right now
# once I figure out what I really want here, I'll work on doing it right
# so far it is effective for conveniently building and running images for testing
{
  pkgs,
  caligaConfigs,
}:
let
  caligaImages = builtins.mapAttrs (_: eval: {
    name = eval.config.layeredImage.name;
    tag = eval.config.layeredImage.tag;
  }) caligaConfigs;

  imageNames = builtins.attrNames caligaConfigs;
  imageNamesStr = builtins.concatStringsSep " " imageNames;

  imageMapEntries = builtins.concatStringsSep "\n" (
    builtins.map (
      name: "IMAGE_MAP[${name}]=\"${caligaImages.${name}.name}:${caligaImages.${name}.tag}\""
    ) imageNames
  );

  bin = pkgs.writeShellScriptBin "caliga" ''
        set -e

        REPO_ROOT="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"

        declare -A IMAGE_MAP
        ${imageMapEntries}

        usage() {
          cat <<EOF
      caliga build [--vm] [--installer-iso] [--regen-initramfs] <imagename>
                                           Build and load an image from the flake
      caliga run [--vm] <imagename>        Run an image (podman or qcow2 VM)
      caliga exec <imagename>              Exec into a running container by image
      caliga stop                          Stop all running containers from flake images
      caliga list                          List flake images loaded in podman
      caliga list running                  List running containers from flake images

    Available images: ${imageNamesStr}
    EOF
          exit "''${1:-0}"
        }

        resolve() {
          local imagename="$1"
          [[ -v IMAGE_MAP[$imagename] ]] || { echo "Unknown image: '$imagename'"; echo "Available images: ${imageNamesStr}"; exit 1; }
          echo "''${IMAGE_MAP[$imagename]}"
        }

        if [ $# -lt 1 ]; then
          usage
        fi

        case "$1" in
          -h|--help) usage ;;
        esac

        cmd="$1"
        shift

        case "$cmd" in
          build)
            vm=false
            installer_iso=false
            regen_initramfs=false
            while [[ "''${1:-}" == -* ]]; do
              case "$1" in
                --vm) vm=true; shift ;;
                --installer-iso) installer_iso=true; shift ;;
                --regen-initramfs) regen_initramfs=true; shift ;;
                *) echo "Unknown option: $1"; exit 1 ;;
              esac
            done
            [ $# -eq 1 ] || { echo "Usage: caliga build [--vm] [--installer-iso] [--regen-initramfs] <imagename>"; echo "Available images: ${imageNamesStr}"; exit 1; }
            imagename="$1"
            image=$(resolve "$imagename")
            echo "Building image '$imagename'..."
            path=$(nix build ".#caligaConfigurations.${pkgs.stdenv.hostPlatform.system}.$imagename.config.build.image" --no-link --print-out-paths)
            echo "Loading image from $path..."
            sudo -v
            "$path" | sudo podman load

            if $regen_initramfs; then
              echo "Regenerating initramfs for '$image'..."
              containerfile=$(mktemp /tmp/caliga-regen-XXXXXX.Containerfile)
              trap 'rm -f "$containerfile"' EXIT
              cat > "$containerfile" <<EOF
    FROM $image
    RUN kver=\$(cd /usr/lib/modules && echo *) && \
        dracut --no-hostonly -vf /usr/lib/modules/\$kver/initramfs.img \$kver
    EOF
              sudo podman build -t "$image" -f "$containerfile" "$(dirname "$containerfile")"
            fi

            if $vm; then
              outdir="$REPO_ROOT/tmp/$imagename"
              mkdir -p "$outdir"
              configfile=$(mktemp /tmp/bib-config-XXXXXX.toml)
              trap 'rm -f "$configfile" "''${containerfile:-}"' EXIT
              cat > "$configfile" <<'TOML'
    [[customizations.filesystem]]
    mountpoint = "/"
    minsize = "20 GiB"
    TOML
              echo "Building raw disk image for '$imagename'..."
              sudo podman run --rm -it --privileged \
                --pull=newer \
                -v /var/lib/containers/storage:/var/lib/containers/storage \
                -v "$outdir":/output \
                -v "$configfile":/config.toml:ro \
                quay.io/centos-bootc/bootc-image-builder:latest \
                --type raw \
                --rootfs ext4 \
                "$image"
              echo "raw disk image written to $REPO_ROOT/tmp/$imagename/image/disk.raw"
            fi

            if $installer_iso; then
              outdir="$REPO_ROOT/tmp/$imagename"
              mkdir -p "$outdir"
              echo "Building installer ISO for '$imagename'..."
              sudo podman run --rm -it --privileged \
                --security-opt label=type:unconfined_t \
                --pull=newer \
                -v /var/lib/containers/storage:/var/lib/containers/storage \
                -v "$outdir":/output \
                -v ${./installer-iso.toml}:/config.toml:ro \
                quay.io/centos-bootc/bootc-image-builder:latest \
                --type anaconda-iso \
                --rootfs ext4 \
                "$image"
              echo "Installer ISO written to $outdir/bootiso/install.iso"
            fi
            ;;

          run)
            vm=false
            while [[ "''${1:-}" == -* ]]; do
              case "$1" in
                --vm) vm=true; shift ;;
                *) echo "Unknown option: $1"; exit 1 ;;
              esac
            done
            [ $# -eq 1 ] || { echo "Usage: caliga run [--vm] <imagename>"; echo "Available images: ${imageNamesStr}"; exit 1; }
            imagename="$1"
            image=$(resolve "$imagename")

            if $vm; then
              raw_path="$REPO_ROOT/tmp/$imagename/image/disk.raw"
              if [ ! -f "$raw_path" ]; then
                echo "No raw disk image found at $raw_path"
                echo "Run 'caliga build --vm $imagename' first"
                exit 1
              fi
              echo "Running VM for '$imagename'..."
              sudo ${pkgs.qemu}/bin/qemu-system-x86_64 \
                -M q35 \
                -m 2048 \
                -cpu host \
                -enable-kvm \
                -nographic \
                -serial mon:stdio \
                -drive file="$raw_path",format=raw,if=virtio \
                -nic user,model=virtio-net-pci
            else
              echo "Running image '$imagename' ($image)..."
              exec sudo podman run -it --rm \
                --privileged \
                --tmpfs /tmp \
                --tmpfs /run \
                -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
                "$image" /sbin/init
            fi
            ;;

          exec)
            [ $# -eq 1 ] || { echo "Usage: caliga exec <imagename>"; echo "Available images: ${imageNamesStr}"; exit 1; }
            image=$(resolve "$1")
            cid=$(sudo podman ps -q --filter "ancestor=$image" | head -n1)
            if [ -z "$cid" ]; then
              echo "No running container found for image '$1' ($image)"
              exit 1
            fi
            echo "Exec into container $cid ($image)..."
            exec sudo podman exec -it "$cid" /bin/bash
            ;;

          stop)
            echo "Stopping all running containers from flake images..."
            found=false
            for ref in "''${IMAGE_MAP[@]}"; do
              ids=$(sudo podman ps -q --filter "ancestor=$ref" 2>/dev/null || true)
              if [ -n "$ids" ]; then
                found=true
                echo "Stopping containers for '$ref'..."
                sudo podman stop $ids
              fi
            done
            $found || echo "No running containers from flake images"
            ;;

          list)
            subcmd="''${1:-}"
            case "$subcmd" in
              running)
                args=()
                for ref in "''${IMAGE_MAP[@]}"; do
                  args+=(--filter "ancestor=$ref")
                done
                sudo podman ps "''${args[@]}" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" 2>/dev/null || true
                ;;
              "")
                for name in "''${!IMAGE_MAP[@]}"; do
                  ref="''${IMAGE_MAP[$name]}"
                  if sudo podman image exists "$ref" 2>/dev/null; then
                    echo "$name  ($ref)  [loaded]"
                  else
                    echo "$name  ($ref)  [not loaded]"
                  fi
                done
                ;;
              *)
                echo "Unknown subcommand: $subcmd"
                usage 1
                ;;
            esac
            ;;

          *)
            echo "Unknown command: $cmd"
            usage 1
            ;;
        esac
  '';

  completion = pkgs.writeText "caliga-completion.bash" ''
    _caliga() {
      local cur prev commands image_names
      COMPREPLY=()
      cur="''${COMP_WORDS[COMP_CWORD]}"
      prev="''${COMP_WORDS[COMP_CWORD-1]}"
      commands="build run exec stop list --help"
      image_names="${imageNamesStr}"

      if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
      fi

      case "$prev" in
        build|run|exec)
          COMPREPLY=( $(compgen -W "$image_names" -- "$cur") )
          ;;
        --vm|--installer-iso|--regen-initramfs)
          COMPREPLY=( $(compgen -W "$image_names" -- "$cur") )
          ;;
        list)
          COMPREPLY=( $(compgen -W "running" -- "$cur") )
          ;;
      esac
      return 0
    }
    complete -F _caliga caliga
  '';
in
pkgs.symlinkJoin {
  name = "caliga-cli";
  paths = [ bin ];
  postBuild = ''
    mkdir -p $out/share/bash-completion/completions
    cp ${completion} $out/share/bash-completion/completions/caliga
  '';
}
