# name + test image + test file
{ pkgs, lib }:
{
  mkRunner =
    {
      name,
      image,
      testFile,
    }:
    pkgs.writeShellApplication {
      name = "caliga-test-${name}";
      runtimeInputs = [
        pkgs.podman
        pkgs.coreutils
        pkgs.gnugrep
      ];
      text = ''
        VM="caliga-test-${name}"
        IMAGE="localhost/caliga-tests:${name}"

        # distrobox: export CONTAINER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
        bcvk() {
          if [ -n "''${CONTAINER_ID:-}" ] && command -v distrobox-host-exec >/dev/null 2>&1; then
            local args
            printf -v args '%q ' "$@"
            distrobox-host-exec env -u CONTAINER_HOST bash -lc "export PATH=/var/home/$USER/.local/bin:\$PATH; bcvk $args"
          else
            env -u CONTAINER_HOST command bcvk "$@"
          fi
        }

        testdir="$(mktemp -d /tmp/caliga-test-${name}.XXXXXXXXXX)"
        cp -r ${../bats}/. "$testdir/"

        # shellcheck disable=SC2329
        cleanup() {
          podman rm -f "$VM" >/dev/null 2>&1 || true
          rm -rf "$testdir"
        }
        trap cleanup EXIT

        podman rm -f "$VM" >/dev/null 2>&1 || true

        echo "Streaming image into podman"
        ${image} | podman load -q

        echo "Booting $VM & executing ${testFile}"

        bcvk ephemeral run --detach --name "$VM" \
          --ro-bind "$testdir:tests" \
          --execute "sh -c 'bats /run/virtiofs-mnt-tests/${testFile}; rc=\$?; echo CALIGA_TEST_EXIT:\$rc; poweroff -f'" \
          "$IMAGE"

        podman wait "$VM" >/dev/null 2>&1 || true
        logs="$(podman logs "$VM" 2>&1)"
        echo "$logs"

        rc="$(grep -oP 'CALIGA_TEST_EXIT:\K[0-9]+' <<< "$logs" | tail -1)"
        exit "$rc"
      '';
    };
}
