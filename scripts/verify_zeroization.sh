#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REDIS_DIR="$ROOT_DIR/vendor/redis-7.4.2"
ALR_BIN="$ROOT_DIR/.tools/alr/bin/alr"
SERVER_BIN="$REDIS_DIR/src/redis-server"
CLI_BIN="$REDIS_DIR/src/redis-cli"
PORT="6391"
MARKER="SPARK-ERASE-MARKER-001"
PID_FILE="$ROOT_DIR/build/redis-secure.pid"
LOG_FILE="$ROOT_DIR/build/redis-secure.log"

mkdir -p "$ROOT_DIR/build"

GNAT_RUNTIME_LIB_DIR="$($ALR_BIN exec -- python3 - <<'PY'
import subprocess
out = subprocess.check_output(['gnatls', '-v'], text=True)
lines = out.splitlines()
in_obj = False
for line in lines:
    if line.startswith('Object Search Path:'):
        in_obj = True
        continue
    if in_obj:
        value = line.strip()
        if not value or value == '<Current_Directory>':
            continue
        print(value)
        break
PY
)"

export DYLD_LIBRARY_PATH="$GNAT_RUNTIME_LIB_DIR:${DYLD_LIBRARY_PATH:-}"

if [ ! -x "$SERVER_BIN" ] || [ ! -x "$CLI_BIN" ]; then
  echo "redis binaries not found, run scripts/build_secure_redis.sh" >&2
  exit 1
fi

cleanup() {
  "$CLI_BIN" -p "$PORT" shutdown nosave >/dev/null 2>&1 || true
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$PID_FILE"
  fi
}

wait_for_redis() {
  local n
  for n in $(seq 1 100); do
    if "$CLI_BIN" -p "$PORT" ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

cleanup
trap cleanup EXIT

"$SERVER_BIN" --save "" --appendonly no --port "$PORT" --daemonize yes --pidfile "$PID_FILE" --logfile "$LOG_FILE"

if ! wait_for_redis; then
  echo "redis did not become ready on port $PORT" >&2
  exit 1
fi

"$CLI_BIN" -p "$PORT" set spark:test "$MARKER" >/dev/null
"$CLI_BIN" -p "$PORT" del spark:test >/dev/null

sleep 0.5

REDIS_PID="$(cat "$PID_FILE")"

LLDB_CMD="$ROOT_DIR/build/verify.lldb"
cat > "$LLDB_CMD" <<EOF
attach -p $REDIS_PID
expr -l c -- ({ extern long long secure_pool_find_pattern(const char *, unsigned long); secure_pool_find_pattern("$MARKER", ${#MARKER}UL); })
detach
quit
EOF

OUTPUT="$ROOT_DIR/build/verify-zeroization.txt"
lldb -b -s "$LLDB_CMD" > "$OUTPUT" 2>&1 || true

if grep -q "= -1" "$OUTPUT"; then
  echo "zeroization verification passed"
else
  echo "zeroization verification failed" >&2
  cat "$OUTPUT" >&2
  exit 1
fi
