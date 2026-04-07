# REMOTE must be set and accept a single shell command string as its last argument.
#   SSH:         REMOTE="ssh ... root@host"
#   Podman exec: REMOTE="podman exec CID bash -lc"
#
# check <name> <cmd>                  — pass if cmd exits 0
# check_contains <name> <cmd> <str>   — pass if cmd output contains str
FAILURES=0

run() {
  $REMOTE "$*"
}

check() {
  local name="$1" cmd="$2"
  printf "%-50s" "$name"
  if run "$cmd" >/dev/null 2>&1; then echo "OK"; else echo "FAIL"; FAILURES=$((FAILURES + 1)); fi
}

check_contains() {
  local name="$1" cmd="$2" expected="$3"
  printf "%-50s" "$name"
  local out; out=$(run "$cmd" 2>&1) || true
  if echo "$out" | grep -qF "$expected"; then echo "OK"; else echo "FAIL: $out"; FAILURES=$((FAILURES + 1)); fi
}

summary() {
  echo ""
  if [ "$FAILURES" -eq 0 ]; then
    echo "PASS"
  else
    echo "FAIL: $FAILURES check(s) failed"
    return 1
  fi
}
