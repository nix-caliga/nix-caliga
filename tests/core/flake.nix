{
  description = "nix-caliga automated tests";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "path:../..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-caliga,
    }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;

      baseImages = {
        fedora-43 = {
          imageName = "quay.io/fedora/fedora-bootc";
          imageDigest = "sha256:9d7a12d886dd2a50589d141b3d71d5dad520b3e131680356dccd484bc171e03e";
          hash = "sha256-kcMauTmPURq4orl6k6pBb3FejZXBpHgNeK2lnNkQh5g=";
          finalImageTag = "43";
        };
        aurora = {
          imageName = "ghcr.io/ublue-os/aurora";
          imageDigest = "sha256:467876f66c1d00a0d59fb6d290e80347ff78f55d91f4f5db89761dffc890a090";
          hash = "sha256-MZmRAVASvBwFnVprKet///5q+ADjZ4bUICVzC8X+f8s=";
          finalImageName = "ghcr.io/ublue-os/aurora";
          finalImageTag = "stable";
        };
      };

      testChecks = ''
        check "selinux file_contexts.local"  "test -f /etc/selinux/targeted/contexts/files/file_contexts.local"
        check "selinux nix store ctx"        "grep -q /nix/store /etc/selinux/targeted/contexts/files/file_contexts.local"
        check "bootc-update timer"           "systemctl is-active bootc-update.timer"
        check "test user home"               "test -d /var/home/test"
        check "tmpfiles config"              "test -f /usr/lib/tmpfiles.d/00-nix-caliga.conf"
        check_contains "tmpfiles new file"   "cat /var/tmp/caliga-test" "tmpfiles working"
        check_contains "bootc-fetch masked"  "systemctl is-enabled bootc-fetch-apply-updates.service 2>&1 || true" "masked"
        check_contains "sleep.target masked" "systemctl is-enabled sleep.target 2>&1 || true" "masked"
        check_contains "test user uid"       "id test" "uid=1001"
        check "cowsay in PATH"               "cowsay test"
        check "nix-daemon socket active"     "systemctl is-active nix-daemon.socket"
        check "nix-directory-setup"          "systemctl is-active nix-directory-setup.service"
        check "nix.conf exists"              "test -f /etc/nix/nix.conf"
        check_contains "nix.conf nixpkgs"    "cat /etc/nix/nix.conf" "nix-path = nixpkgs=/nix/store/"
        check_contains "nix --version"       "nix --version" "nix"
        check "nix-shell -p hello"           "nix-shell -p hello --run hello"
      '';

      mkTest =
        name: image:
        let
          testConfig = nix-caliga.lib.makeCaligaConfig {
            inherit pkgs;
            modules = [
              (
                { pkgs, ... }:
                {
                  layeredImage = {
                    name = "localhost/caliga-test-${name}";
                    tag = "test";
                    fromImage = pkgs.dockerTools.pullImage {
                      inherit (image)
                        imageName
                        imageDigest
                        hash
                        finalImageTag
                        ;
                    };
                  };

                  system.stateVersion = "25.11";
                  systemd.defaultUnit = "multi-user.target";

                  users.users.root = {
                    hashedPassword = "";
                  };
                  users.users.test = {
                    isNormalUser = true;
                    uid = 1001;
                    description = "Test User";
                    initialPassword = "test";
                  };

                  services.bootc-update = {
                    enable = true;
                    schedule = {
                      onBootSec = "20s";
                      onUnitActiveSec = "20s";
                    };
                  };

                  environment.systemPackages = [ pkgs.cowsay ];

                  systemd.tmpfiles.rules = [ "f /var/tmp/caliga-test 0644 root root - tmpfiles working" ];

                  systemd.maskedUnits = [ "sleep.target" ];

                  nix.enable = true;
                }
              )
            ];
          };

          imageStream = testConfig.config.build.image;
          imageRef = "${testConfig.config.layeredImage.name}:${testConfig.config.layeredImage.tag}";

          podmanRunner = pkgs.writeShellScriptBin "caliga-test-${name}" ''
            set -euo pipefail

            CID=""
            cleanup() {
              [ -n "$CID" ] && sudo ${pkgs.podman}/bin/podman rm -ft2 "$CID" >/dev/null 2>&1 || true
            }
            trap cleanup EXIT

            ${imageStream} | sudo ${pkgs.podman}/bin/podman load >/dev/null 2>&1
            CID=$(sudo ${pkgs.podman}/bin/podman run -d --privileged --tmpfs /tmp --tmpfs /run \
              -v /sys/fs/cgroup:/sys/fs/cgroup:ro "${imageRef}" /sbin/init)

            for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
              sudo ${pkgs.podman}/bin/podman exec $CID \
                systemctl is-active --quiet multi-user.target 2>/dev/null && break
              sleep 1
            done

            if [ "''${1:-}" = "--shell" ]; then
              sudo ${pkgs.podman}/bin/podman exec -it $CID bash -l
              exit 0
            fi

            REMOTE="sudo ${pkgs.podman}/bin/podman exec $CID bash -lc"
            export REMOTE
            source ${./check.sh}

            echo "testing ${name}"
            ${testChecks}
            summary || result=1
            exit "''${result:-0}"
          '';

          qemuRunner = pkgs.writeShellScriptBin "caliga-test-${name}-vm" ''
            set -euo pipefail

            TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
            cleanup() {
              sudo ${pkgs.coreutils}/bin/rm -rf "$TMPDIR"
            }
            trap cleanup EXIT

            ${imageStream} | sudo ${pkgs.podman}/bin/podman load >/dev/null 2>&1

            configfile="$TMPDIR/config.toml"
            cat > "$configfile" <<'TOML'
            [[customizations.filesystem]]
            mountpoint = "/"
            minsize = "60 GiB"
            TOML

            sudo ${pkgs.podman}/bin/podman run --rm --privileged \
              -v /var/lib/containers/storage:/var/lib/containers/storage \
              -v "$TMPDIR":/output \
              -v "$configfile":/config.toml:ro \
              quay.io/centos-bootc/bootc-image-builder:latest \
              --type raw --rootfs ext4 "${imageRef}"

            exec sudo ${pkgs.qemu}/bin/qemu-system-x86_64 \
              -M q35 -m 2048 -cpu host -enable-kvm \
              -nographic \
              -drive file="$TMPDIR/image/disk.raw",format=raw,if=virtio \
              -nic user,model=virtio-net-pci
          '';
        in
        {
          test = podmanRunner;
          test-vm = qemuRunner;
        };

      tests = lib.mapAttrs mkTest baseImages;

      mkAllRunner =
        attr: suffix:
        pkgs.writeShellScript "caliga-test-all${suffix}" ''
          failed_images=""
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: t: ''
              if ${t.${attr}}/bin/caliga-test-${name}${suffix}; then :; else failed_images="$failed_images ${name}"; fi
            '') tests
          )}
          if [ -z "$failed_images" ]; then
            echo "All images passed."
          else
            echo "Failed:$failed_images"
            exit 1
          fi
        '';
    in
    {
      packages.x86_64-linux =
        lib.mapAttrs (_: t: t.test) tests
        // lib.mapAttrs' (n: t: lib.nameValuePair "${n}-vm" t.test-vm) tests
        // {
          default = tests.fedora-43.test;
          all = pkgs.writeShellScriptBin "caliga-test-all" ''
            exec ${mkAllRunner "test" ""}
          '';
          all-vm = pkgs.writeShellScriptBin "caliga-test-all-vm" ''
            exec ${mkAllRunner "test-vm" "-vm"}
          '';
        };
    };
}
