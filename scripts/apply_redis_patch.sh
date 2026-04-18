#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REDIS_DIR="$ROOT_DIR/vendor/redis-7.4.2"
PATCH_FILE="$ROOT_DIR/patches/redis-7.4.2-secure-zmalloc.patch"

if [ ! -d "$REDIS_DIR/.git" ]; then
  echo "missing redis source at $REDIS_DIR" >&2
  exit 1
fi

if grep -q "USE_SECURE_SPARK_ALLOCATOR" "$REDIS_DIR/src/zmalloc.h" \
  && grep -q "zmalloc_secure_allocator_init" "$REDIS_DIR/src/server.c"
then
  exit 0
fi

git -C "$REDIS_DIR" apply --check "$PATCH_FILE"
git -C "$REDIS_DIR" apply "$PATCH_FILE"
