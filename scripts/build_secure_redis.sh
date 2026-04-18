#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REDIS_DIR="$ROOT_DIR/vendor/redis-7.4.2"
ALR_BIN="$ROOT_DIR/.tools/alr/bin/alr"

"$ROOT_DIR/scripts/build_secure_allocator.sh"
"$ROOT_DIR/scripts/apply_redis_patch.sh"

GNAT_LIB="$($ALR_BIN exec -- gcc -print-file-name=libgnat.a)"
if [ "$GNAT_LIB" = "libgnat.a" ]; then
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
else
  GNAT_RUNTIME_LIB_DIR="$(dirname "$GNAT_LIB")"
fi

make -C "$REDIS_DIR/src" distclean MALLOC=libc
make -C "$REDIS_DIR/src" USE_SECURE_SPARK_ALLOCATOR=yes SECURE_ALLOCATOR_LIB_DIR="$ROOT_DIR/build/lib" GNAT_RUNTIME_LIB_DIR="$GNAT_RUNTIME_LIB_DIR"
