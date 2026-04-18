#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"
ALIRE_VERSION="2.1.0"
ALIRE_ARCHIVE="alr-${ALIRE_VERSION}-bin-universal-macos.zip"
ALIRE_URL="https://github.com/alire-project/alire/releases/download/v${ALIRE_VERSION}/${ALIRE_ARCHIVE}"

mkdir -p "$TOOLS_DIR"

if [ ! -x "$TOOLS_DIR/alr/bin/alr" ]; then
  curl -L "$ALIRE_URL" -o "$TOOLS_DIR/$ALIRE_ARCHIVE"
  rm -rf "$TOOLS_DIR/alr"
  mkdir -p "$TOOLS_DIR/alr"
  unzip -q "$TOOLS_DIR/$ALIRE_ARCHIVE" -d "$TOOLS_DIR/alr"
  xattr -d com.apple.quarantine "$TOOLS_DIR/alr/bin/alr" >/dev/null 2>&1 || true
fi

export PATH="$TOOLS_DIR/alr/bin:$PATH"

alr --version
alr index --update-all
alr toolchain --select gnat_native=15.1.2 || true
alr toolchain --select gprbuild || true

cd "$ROOT_DIR"
alr -n update
