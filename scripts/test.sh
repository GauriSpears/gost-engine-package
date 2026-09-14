#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/gost-src"
GOST_BIN="${NODE_BIN:-$SRC_DIR/build/bin}"

if [[ ! -x "$GOST_BIN" ]]; then
  echo "Gost-engine binary not found: $GOST_BIN" >&2
  exit 1
fi

if ! openssl list -providers | grep -i gost; then
  echo "Gost provider failed to load" >&2
  exit 1
fi

if ! openssl list -digest-algorithms | grep -i gost; then
  echo "Gost provider algorithms failed to load" >&2
  exit 1
fi

echo "==> All tests passed"
