#!/usr/bin/env bash
set -euo pipefail

GOST_SHA="${GOST_SHA:?}"
BUILD_ID="${BUILD_ID:-master-${GOST_SHA:0:12}}"
DISTRO="${DISTRO:?}"
DISTRO_VERSION="${DISTRO_VERSION:-}"
BUILD_ROOT="${BUILD_ROOT:-$(pwd)/build}"
SRC_DIR="${BUILD_ROOT}/gost-src"
OUT="${OUT_DIR:-$(pwd)/out}"
PREFIX="/usr"
# Version string for packages: 0.0.0+master.<sha12> (valid enough for fpm/dpkg)
VERSION="0.0.0+master.${GOST_SHA:0:12}"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) DEB_ARCH=amd64; RPM_ARCH=x86_64 ;;
  aarch64) DEB_ARCH=arm64; RPM_ARCH=aarch64 ;;
  *) DEB_ARCH="$ARCH"; RPM_ARCH="$ARCH" ;;
esac

mkdir -p "$OUT"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

echo "==> Staging into $STAGE$PREFIX"
DESTDIR="$STAGE$PREFIX" cmake --install "$SRC_DIR" --config Release

PKG_NAME="gost-engine"
DESCRIPTION="Gost-engine master@${GOST_SHA:0:12}"

package_deb() {
  local suite="${DISTRO_VERSION:-unknown}"
  local deb_ver="${VERSION}-1+${suite}"
  if command -v fpm >/dev/null 2>&1; then
    fpm -s dir -t deb -n "$PKG_NAME" -v "$VERSION" --iteration "1+${suite}" \
      -a "$DEB_ARCH" --description "$DESCRIPTION" --url "https://github.com/GauriSpears/gost-engine-package" \
      --depends "libssl3" -C "$STAGE" usr || true
    mv -f ${PKG_NAME}_*.deb "$OUT/" 2>/dev/null || true
  fi
  if ! ls "$OUT"/*.deb >/dev/null 2>&1; then
    mkdir -p "$STAGE/DEBIAN"
    local size; size=$(du -sk "$STAGE/usr" 2>/dev/null | awk '{print $1}')
    cat > "$STAGE/DEBIAN/control" <<CTRL
Package: $PKG_NAME
Version: $deb_ver
Section: web
Priority: optional
Architecture: $DEB_ARCH
mastertainer: gost-engine-package CI <ci@localhost>
Depends: libssl3, libc6
Installed-Size: ${size:-1}
Description: $DESCRIPTION
CTRL
    dpkg-deb --build "$STAGE" "$OUT/${PKG_NAME}_${deb_ver}_${DEB_ARCH}.deb"
  fi
}

package_rpm() {
  local el="${DISTRO_VERSION:-el}"
  if command -v fpm >/dev/null 2>&1; then
    fpm -s dir -t rpm -n "$PKG_NAME" -v "0.0.0" --iteration "1.master.${GOST_SHA:0:12}.${el}" \
      -a "$RPM_ARCH" --description "$DESCRIPTION" --depends "openssl-libs" \
      -C "$STAGE" usr || true
    mv -f ${PKG_NAME}-*.rpm "$OUT/" 2>/dev/null || true
  fi
  if ! ls "$OUT"/*.rpm >/dev/null 2>&1; then
    tar -C "$STAGE" -czf "$OUT/${PKG_NAME}-0.0.0-1.master.${GOST_SHA:0:12}.${el}.${RPM_ARCH}.tar.gz" usr
  fi
}

package_arch() {
  if command -v fpm >/dev/null 2>&1; then
    fpm -s dir -t pacman -n "$PKG_NAME" -v "0.0.0+master.${GOST_SHA:0:12}" --iteration 1 \
      -a "$ARCH" --description "$DESCRIPTION" -C "$STAGE" usr || true
    mv -f ${PKG_NAME}-*.pkg.tar* "$OUT/" 2>/dev/null || true
  fi
  if ! ls "$OUT"/${PKG_NAME}-* >/dev/null 2>&1; then
    if command -v zstd >/dev/null; then
      tar -C "$STAGE" -cf - usr | zstd -o "$OUT/${PKG_NAME}-0.0.0+master.${GOST_SHA:0:12}-1-${ARCH}.pkg.tar.zst"
    else
      tar -C "$STAGE" -czf "$OUT/${PKG_NAME}-0.0.0+master.${GOST_SHA:0:12}-1-${ARCH}.tar.gz" usr
    fi
  fi
}

case "$DISTRO" in
  debian|ubuntu) package_deb ;;
  almalinux|rhel|fedora|centos) package_rpm ;;
  arch|archlinux) package_arch ;;
  *) tar -C "$STAGE" -czf "$OUT/${PKG_NAME}-${BUILD_ID}-${DISTRO}-${ARCH}.tar.gz" usr ;;
esac

ls -la "$OUT"
