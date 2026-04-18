#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"
PROFILE="${PROFILE:-strict}"
LOG_FILE="${LOG_FILE:-}"

export PATH="$TOOLS_DIR/alr/bin:$PATH"

cd "$ROOT_DIR"
alr -n update

if [ "$PROFILE" = "strict" ]; then
  CMD=(alr exec -- gnatprove -P secure_allocator.gpr --steps=0 --timeout=0 --mode=all --level=4 --proof=progressive --prover=cvc5,z3 --checks-as-errors=on --warnings=on --report=all --output=oneline)
elif [ "$PROFILE" = "passed" ]; then
  CMD=(alr exec -- gnatprove -P secure_allocator.gpr -U -j0 --steps=200 --timeout=10 --mode=all --level=2 --proof=progressive --prover=cvc5,z3 --checks-as-errors=off --warnings=off --report=statistics --output=oneline)
else
  echo "unknown PROFILE '$PROFILE'" >&2
  exit 1
fi

if [ -n "$LOG_FILE" ]; then
  "${CMD[@]}" > "$LOG_FILE" 2>&1
else
  "${CMD[@]}"
fi
