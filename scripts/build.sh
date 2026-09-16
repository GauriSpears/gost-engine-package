#!/usr/bin/env bash
# Clone gost-engine/engine at GOST_SHA (master HEAD), cmake, build.
set -euo pipefail

GOST_SHA="${GOST_SHA:?set GOST_SHA (full git commit on gost-engine/engine)}"
BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/gost-src"
ENGINE_PATH=$(openssl version -a 2>/dev/null | sed -n 's/.*ENGINESDIR: "\([^"]*\)".*/\1/p' || true)
MOD_PATH=$(openssl version -a 2>/dev/null | sed -n 's/.*MODULESDIR: "\([^"]*\)".*/\1/p' || true)
#MULTIARCH=$(gcc -print-multiarch 2>/dev/null || dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
#LIBDIR="/usr/lib/${MULTIARCH}"

LIBCRYPTO=""
for candidate in \
  /usr/lib64/libcrypto.so \
  /usr/lib/x86_64-linux-gnu/libcrypto.so \
  /usr/lib/libcrypto.so \
  /usr/lib/*/libcrypto.so
do
  if [[ -e "$candidate" ]]; then
    LIBCRYPTO="$candidate"
    break
  fi
done

LIBSSL=""
for candidate in \
  /usr/lib64/libssl.so \
  /usr/lib/x86_64-linux-gnu/libssl.so \
  /usr/lib/libssl.so \
  /usr/lib/*/libssl.so
do
  if [[ -e "$candidate" ]]; then
    LIBSSL="$candidate"
    break
  fi
done

if [[ -z "$LIBCRYPTO" || -z "$LIBSSL" ]]; then
  echo "ERROR: could not find libcrypto.so / libssl.so" >&2
  find /usr -name 'libcrypto.so*' 2>/dev/null | head -10
  exit 1
fi

echo "==> Using OpenSSL libraries:"
echo "    crypto: $LIBCRYPTO"
echo "    ssl:    $LIBSSL"
echo "    engines: ${ENGINE_PATH:-<default>}"

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
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DOPENSSL_ROOT_DIR=/usr \
  -DOPENSSL_ENGINES_DIR="${ENGINE_PATH}" \
  -DOPENSSL_MODULES_DIR=${MOD_PATH} \
  -DOPENSSL_CRYPTO_LIBRARY="${LIBCRYPTO}" \
  -DOPENSSL_SSL_LIBRARY="${LIBSSL}" \
  -DOPENSSL_INCLUDE_DIR=/usr/include \
  ..

cmake --build . --config Release
cmake --install . --config Release

pwd

echo "==> Gost-engine build finished"
