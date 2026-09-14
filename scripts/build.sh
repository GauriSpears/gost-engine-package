#!/usr/bin/env bash
# Clone gost-engine/engine at GOST_SHA (main HEAD), cmake, build.
set -euo pipefail

GOST_SHA="${GOST_SHA:?set GOST_SHA (full git commit on gost-engine/engine)}"
BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/gost-src"
ENGINE_PATH=$(openssl version -a | grep -Po '(?<=ENGINESDIR: ")[^"]*')
MOD_PATH=$(openssl version -a | grep -Po '(?<=MODULESDIR: ")[^"]*')
MULTIARCH=$(gcc -print-multiarch 2>/dev/null || dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
LIBDIR="/usr/lib/${MULTIARCH}"

mkdir -p "$BUILD_ROOT"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "==> Cloning gost-engine/engine"
  git clone --filter=blob:none --no-checkout https://github.com/gost-engine/engine.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --depth=1 origin "$GOST_SHA" 2>/dev/null \
  || git fetch --depth=1 origin master
git checkout --force "$GOST_SHA" 2>/dev/null \
  || { git fetch --depth=50 origin master; git checkout --force "$GOST_SHA" 2>/dev/null; } \
  || git checkout --force master
git submodule update --init

echo "==> Building commit $(git rev-parse HEAD)"
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local/src/etest \
  -DOPENSSL_ROOT_DIR=/usr \
  -DOPENSSL_ENGINES_DIR="${ENGINE_PATH}" \
  -DOPENSSL_CRYPTO_LIBRARY="${LIBDIR}/libcrypto.so" \
  -DOPENSSL_SSL_LIBRARY="${LIBDIR}/libssl.so" \
  -DOPENSSL_INCLUDE_DIR=/usr/include \
  ..

cmake --build . --config Release
cmake --install . --config Release

echo "==> Gost-engine build finished"
