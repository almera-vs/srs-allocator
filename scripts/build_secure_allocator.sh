#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"

export PATH="$TOOLS_DIR/alr/bin:$PATH"

cd "$ROOT_DIR"
alr -n update
alr build
