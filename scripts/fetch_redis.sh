#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor"
REDIS_TAG="7.4.2"
REDIS_DIR="$VENDOR_DIR/redis-${REDIS_TAG}"

mkdir -p "$VENDOR_DIR"

rm -rf "$REDIS_DIR"
git clone --branch "$REDIS_TAG" --depth 1 https://github.com/redis/redis.git "$REDIS_DIR"

"$ROOT_DIR/scripts/apply_redis_patch.sh"
